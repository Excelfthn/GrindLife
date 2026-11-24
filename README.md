# Life RPG Scheduler

A gamified weekly schedule and to-do app built with Flutter. Finish tasks and focus sessions to earn XP, level up, and grow four attributes (INT, STR, CHA, WIS).

## Version 0.1 (local data)

- Weekly schedule table with colored blocks per attribute
- Add schedules manually: repeat once, daily, weekly (multiple days) or monthly, with end options (never, on date, after N times)
- Tasks per schedule with Easy, Medium, Hard weights; XP shared from a pool based on the schedule length
- Attribute and XP type guessed automatically from the activity name
- Schedule detail popup with location, notes, reminder and a focus timer (25, 50 or 90 minutes, 4 sessions with 5 minute breaks)
- Character profile with level, XP, attributes, streak and weekly review
- Data is stored on the phone (no account yet)

Planned next: Firebase login and sync, notifications, Market with daily quests and coins, AI natural language input, Reality to Loot.

## Getting the APK

Every push to `main` runs the GitHub Actions workflow in `.github/workflows/build-apk.yml`. It generates the Android project, builds a release APK and publishes it under Releases. Open the latest release on your phone and download `app-release.apk`.

## Building locally

```bash
flutter create --platforms=android --project-name life_rpg .
flutter pub get
flutter run
```
