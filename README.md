# Pausely

A gentle **break reminder** app that lives in your Mac's menu bar. Pausely
nudges you to rest your eyes, stand up, drink water, and stretch — so long
focus sessions don't cost you your health.

**Privacy first** — Pausely runs entirely on your Mac using local timers and
Apple's local notifications. No tracking, nothing leaves your device.

## Features
- Four gentle reminders: rest your eyes, stand up, drink water, stretch
- Local notifications + an in-app "next break" countdown
- **Pausely Pro** (one-time purchase): all reminders at once, custom intervals,
  daily stats, sounds & all themes

## Build
The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
open Pausely.xcodeproj
```

CI/CD: built & signed for the Mac App Store on Codemagic (`codemagic.yaml`).
Monetization via [RevenueCat](https://www.revenuecat.com) (entitlement `pro`).

- Bundle ID: `app.pausely.Pausely`
- Minimum macOS: 13.0
