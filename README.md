# Sprout

**Make space. Do the work. Grow.**

A fast, calm, manual-first student focus and behavioral tracking tool.

Sprout is built around the philosophy: **"I live first. I log afterward."**

Instead of managing to-do lists, task queues, and artificial schedules, Sprout acts as a behavioral mirror:
- **Quick Logging**: Record activities, focus levels, and AI assistance in 5–10 seconds.
- **Reality Over Plans**: See where your time actually went across classes, focused study, exercise, and leisure.
- **AI Dependence Tracking**: Monitor independent problem-solving vs. AI-assisted work without judgment.
- **Cumulative Garden**: Real botanical growth earned through genuine focused effort, without streaks or guilt mechanics.

## Stack

SwiftUI, SwiftData, Observation (`@Observable`). Multiplatform with [Skip](https://skip.tools). Local-first. No backend.

## Primary Tabs

- **Today**: Real-time summary and observational timeline (anti-schedule).
- **Log**: 5-second quick capture with recent activity chips.
- **Insights**: Behavior trends, independent study ratios, and weekly reflection.
- **Garden**: Botanical sanctuary representing accumulated focus.

## Tests

```bash
xcodebuild -scheme FocusGarden -destination 'platform=iOS Simulator,name=iPhone 16' test
```
