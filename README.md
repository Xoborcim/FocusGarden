# FocusGarden

iOS 17+ SwiftUI app that turns a school `.ics` into a week of classes and study blocks.

Import a timetable. Class times stay fixed. Study slots are placed around them. Tests and homework get extra blocks before they’re due.

## Stack

SwiftUI, SwiftData, Observation (`@Observable`). Local-first. No backend.

## Tabs

Schedule · Courses · Settings

## Requirements

- Xcode 16+ (iOS 17 deployment target)
- iOS 17 simulator or device

## Getting started

```bash
open FocusGarden.xcodeproj
```

Select an iPhone simulator and run the **FocusGarden** scheme. Use **FocusGarden-Sideload** when you need a build without CloudKit / App Groups.

## How study time is chosen

- Weekly study for each course is **1.5× weekly class time** (at least 60 minutes, at most 6 hours), split into 15–90 minute blocks.
- Tests get extra prep (90–240 minutes) before the exam, never overlapping the exam itself.
- Homework gets a work block (90–150 minutes) before the due date.
- Nothing is placed on top of a class.

## Tests

```bash
xcodebuild -scheme FocusGarden -destination 'platform=iOS Simulator,name=iPhone 16' test
```
