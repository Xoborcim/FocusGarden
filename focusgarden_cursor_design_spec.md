# FocusGarden — Cursor Product + Engineering Design Specification

**Bundle ID:** `com.sebastian.focusgarden`  
**Platform:** iOS 17+  
**Stack:** SwiftUI, SwiftData, CloudKit, Observation (`@Observable`)  
**Core loop:** **plan → do → log → grow**

> Treat this file as the implementation source of truth. Preserve product behavior over incidental implementation suggestions.

## 1. Product Principles

- Schedule schoolwork around real class commitments first.
- Keep capture fast and the first-run UI simple.
- Use progressive disclosure: core tabs remain stable; advanced surfaces unlock after one meaningful action.
- Failure is recoverable through rescheduling, not shame.
- Scheduling must be explainable.
- Local-first: all core flows work offline.
- No external backend APIs.
- Neobrutalist visual language: black, terminal green/amber, monospaced type, thick square borders, hard shadows, zero-radius cards.

### Resolved assumptions

- Bottom tabs are always: **Schedule, Garden, Tasks, Courses, Settings**.
- Beginner mode ends after the first task completion, quick log, or recorded focus session.
- Weekly Review, Disaster Mode, and Thoughts Inbox are advanced surfaces inside existing tabs.
- Disaster Mode is a manual recovery planner that redistributes overdue/incomplete work across the next 7–14 days.

## 2. CloudKit-Compatible SwiftData Rules

1. Never use `@Attribute(.unique)`.
2. Every stored scalar attribute has a default.
3. Every relationship is optional.
4. Never use `.deny` delete rules.
5. Heavy imports/deletes/regeneration use a background `ModelContext` from the same `ModelContainer`.
6. Repositories must tolerate temporarily missing relationships and reconcile logical duplicates.

## 3. Core Models

```swift
@Model final class Task {
    var id: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var priority: Int = 1
    var estimatedMinutes: Int = 0
    var scheduledStart: Date?
    var scheduledEnd: Date?
    var taskKind: String = "standard"
    var isSpacedReview: Bool = false
    @Relationship var linkedCourse: Course?
}

@Model final class Course {
    var id: UUID = UUID()
    var code: String = ""
    var title: String = ""
    @Relationship(deleteRule: .cascade) var tasks: [Task]?
    @Relationship(deleteRule: .cascade) var classBlocks: [ClassBlock]?
}

@Model final class ClassBlock {
    var id: UUID = UUID()
    var dayOfWeek: Int = 1
    var startTime: TimeInterval = 0.0
    var duration: TimeInterval = 0.0
    var cognitiveWeight: Double = 1.0
    @Relationship var course: Course?
}

@Model final class Plant {
    var id: UUID = UUID()
    var name: String = ""
    var species: String = "sunflower"
    var health: Double = 100.0
    var waterLevel: Double = 0.0
    var growthStage: Int = 0
    var streakCount: Int = 0
}
```

Recommended supporting models: `FocusSession`, `QuickLog`, `ThoughtItem`, `DailyGoalRecord`, `PlantLedgerEntry`, `AppStateRecord`, `EncouragementReceipt`.

## 4. Architecture

```text
SwiftUI View
  ↓
@Observable ViewModel
  ↓
Injected Service / Repository Protocol
  ↓
SwiftData ModelContext + CloudKit
```

Suggested services: `ScheduleManager`, `AutoSchedulingEngine`, `PlantManager`, `ICSImportService`, `EncouragementService`, `CloudSyncStatusService`, `DisasterRecoveryService`.

Views never own scheduling or plant formulas.

## 5. Progressive Disclosure

- `hasCompletedOnboarding` and `isBeginnerMode` are persistent independent state.
- Beginner mode shows the five core tabs but hides advanced controls.
- Garden shows **Start Here** until a first meaningful action occurs.
- Once beginner mode ends, do not re-enter except via debug reset.

## 6. Schedule Tab

Primary landing surface. Show a vertical timeline containing fixed class blocks and movable focus/review blocks.

Required behaviors:
- Never overlap a generated task with a class.
- Distinguish fixed classes from movable tasks.
- Expose a human-readable reason on every generated task block.
- Allow Start Focus, Mark Done, and Reschedule.
- Manual placements become soft-locked against ordinary regeneration.
- Advanced mode reveals Disaster Mode, Weekly Review, batching banners, and Thoughts Inbox summary.

## 7. Garden Tab

- Current plant foreground; mature plants shrink/offset backward to mimic z-depth.
- Prefer SwiftUI scale/offset over 3D frameworks for v1.
- Show health, water progress, stage, streak, Quick Log.
- Friends sheet is top-left.
- Beginner state includes Start Here card.
- Overflow water after maturity carries to the next plant.

## 8. Tasks / Courses

Task creation minimum: title, estimated minutes, priority. Course is optional.

Task types: `standard`, `review`, `batch`.

Completion from any screen must route through one completion service so water is granted exactly once.

Courses show recurring class blocks, incomplete work, and advanced workload summary.

## 9. Deep Work

- Full-screen cover launched from scheduled task.
- Create `FocusSession` before presentation.
- Break bank accrues linearly; proposed default 10 break minutes / 60 focused minutes.
- Thoughts Inbox capture does not pause timer.
- Normal finish records minutes and task outcome.
- Intentional early quit requires consequence confirmation and applies a modest health + water penalty exactly once.
- OS termination/crash must not be treated as intentional quit.

## 10. AutoSchedulingEngine

### Hard constraints

- Horizon ≈ 21 days.
- Preferred scheduling window 07:00–23:00 local.
- 15-minute placement granularity.
- 15–90 minute chunks.
- Short configurable buffers.
- Roughly 4 non-review focus blocks/day.
- Never overlap fixed classes or locked blocks.

### Preferences

- High-priority coursework prefers the first strong slot after the final class of the day.
- Spaced reviews prefer later-day slots.
- Deadline urgency can outrank generic priority.
- Heavy work is penalized immediately after high cognitive-weight classes/exams.

### Suggested scoring

```text
score(slot, task) =
    + priorityWeight
    + deadlineUrgency
    + afterFinalClassBonus
    + spacedReviewLateDayBonus
    + continuityBonus
    - cognitiveFatiguePenalty
    - fragmentationPenalty
    - dailyBlockCountPenalty
    - latenessPenalty
```

### Algorithm

1. Expand fixed ClassBlock occupancy across the 21-day horizon.
2. Add preserved user-locked task blocks.
3. Split incomplete tasks into 15–90 minute chunks.
4. Sort by urgency/priority/review semantics.
5. Enumerate free candidate slots in 15-minute increments.
6. Filter hard violations.
7. Score remaining candidates.
8. Select best candidate and reserve block + buffer.
9. Return unscheduled tasks with reasons when no valid slot exists.
10. Persist planning changes transactionally where practical.

### Cognitive load

```text
fatigue(t) = Σ classWeight_i * exp(-decay * hoursSinceClass_i)
slotPenalty = fatigue(slot.start) * taskIntensity(task)
```

## 11. Disaster Mode — Proposed Default

Manual only. Build a preview before committing.

- Collect overdue/incomplete movable tasks + near-term upcoming work.
- Preserve classes and locked work.
- Use a 7–14 day recovery horizon.
- Temporarily allow up to ~5 non-review blocks/day.
- Show moved blocks, overloaded days, and still-unscheduled work.
- Commit only after confirmation.

## 12. ICS Import

Pipeline:

```text
Data (.ics)
→ unfold folded lines
→ parse VCALENDAR/VEVENT
→ resolve TZID + DTSTART/DTEND
→ normalize recurrence
→ infer course code + meeting type
→ group weekly equivalents
→ preview
→ user confirm
→ background SwiftData commit
```

Requirements:
- Respect `TZID=America/Toronto`.
- Parse continuous codes such as `MGT225H5` and spaced forms such as `CHEM 112A 001`.
- `LEC = 1.5`, `TUT = 1.0`, `EXAM = 3.0`; unknown types default to 1.0.
- Partial malformed events produce warnings rather than whole-import failure.
- Deduplicate via logical fingerprint, not SwiftData unique constraints.

## 13. Plant Math

```text
waterYield = baseWater(task)
           × priorityMultiplier
           × activeEncouragementMultiplier
```

Proposed growth targets: 25 / 60 / 120 / 200.

Wilting:

```text
H(t) = H0 * exp(-lambda * t)
lambda = baseDecay + missedGoalStreak * missedGoalStep
```

Compute decay from timestamps/daily records so offline gaps are deterministic.

Encouragement: 1 per friend per rolling 24 hours; suggested 1.5× multiplier on the next eligible task; consumed exactly once.

## 14. Social / CloudKit

- Social scope is shared garden presence + encouragement only.
- Never expose private task text as a side effect of sharing a garden.
- Use UUID/event IDs so completion and encouragement consumption are idempotent across devices.
- Settings sync state: Up to date / Syncing / Offline / Needs attention.

## 15. Settings

Sections: Calendar, Scheduling, Garden, iCloud, Disaster Mode, Debug.

Debug tools (development only): reset onboarding/beginner state, regenerate plan, seed sample semester, sync diagnostics.

## 16. Suggested File Tree

```text
FocusGarden/
├── App/
├── Models/
├── Repositories/
├── Services/
│   ├── Scheduling/
│   ├── Garden/
│   ├── Calendar/
│   └── Sync/
├── Features/
│   ├── Onboarding/
│   ├── Schedule/
│   ├── Garden/
│   ├── Tasks/
│   ├── Courses/
│   ├── DeepWork/
│   └── Settings/
├── DesignSystem/
└── Tests/
```

Inject configuration and a clock/calendar abstraction for deterministic tests.

## 17. AutoSchedulingEngine Test Criteria

Must cover:
- no class overlap;
- preferred-window compliance;
- 15–90 minute chunks aligned to 15 minutes;
- daily cap;
- high-priority post-final-class preference;
- later-day spaced review preference;
- unschedulable reason behavior;
- locked block preservation;
- deterministic outputs;
- Toronto DST boundaries.

Scenario fixtures: light day, packed day, exam day, overloaded week, review-heavy week, manual edits, DST transition, no-class schedule.

Add property-style randomized tests asserting no overlap, valid bounds/durations, and no duplicate assignment.

## 18. App-Wide Testing

PlantManager:
- task completion waters exactly once;
- encouragement consumed exactly once;
- 24-hour sender rate limit;
- deterministic decay across restart/offline gap;
- overflow preserved;
- values clamped.

ICS:
- Toronto timezone correctness;
- both course-code formats;
- class-type weights;
- partial parse resilience;
- logical deduplication.

UI:
- first-run flow;
- beginner unlock without tab rearrangement;
- Deep Work + thoughts;
- early-quit penalty;
- Disaster preview before commit;
- offline core loop.

## 19. Milestones

1. **M1 Skeleton:** app shell, tokens, models, five tabs.
2. **M2 Core loop:** Task CRUD, basic Schedule, Garden rewards, beginner mode.
3. **M3 Calendar:** ICS parser/import and class timeline.
4. **M4 Scheduler:** 21-day engine, reasons, regeneration, tests.
5. **M5 Deep Work:** timer, break bank, thoughts, early-quit penalty.
6. **M6 Cloud/social:** sync status, sharing, encouragement.
7. **M7 Advanced:** Disaster Mode, weekly review, batching, diagnostics.
8. **M8 Polish:** accessibility, performance, migrations, UI tests.

## 20. Cursor Master Build Prompt

```text
You are implementing FocusGarden, an iOS 17+ SwiftUI app using SwiftData, CloudKit, and Observation.

Treat /docs/focusgarden_design_spec.md as the product and engineering source of truth.

Rules:
1. Build milestone-by-milestone and keep the project compiling after each milestone.
2. Use MVVM + repositories + injected services. Views stay declarative.
3. Respect CloudKit-compatible SwiftData constraints: no unique attributes, defaults for stored attributes, optional relationships, no .deny delete rules.
4. Keep all core flows useful offline. Do not add an external backend API.
5. Centralize scheduling, plant math, ICS parsing, and completion side effects in testable services.
6. Add deterministic tests before/with AutoSchedulingEngine and PlantManager.
7. Follow the neobrutalist tokens: black, terminal green/amber, monospaced type, thick square borders, hard shadows, no rounded-card aesthetic.
8. Preserve the five stable bottom tabs. Reveal advanced surfaces only after beginner mode ends.
9. Never silently force an invalid schedule; return unscheduled work with an explanation.
10. Before changing schema or architecture, explain why and verify the change does not violate this document.

Start with M1. Show the proposed file tree, then create the minimal compiling implementation and tests required for that milestone.
```

## 21. Open Prototype Decisions

- Exact water yields and priority multipliers.
- Final growth thresholds.
- Break accrual rate.
- Disaster daily overload cap.
- Whether Quick Logs earn a small plant reward.
- Maximum number of mature plants visible in the depth garden.
