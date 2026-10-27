# Thought Meadow native iPhone app

This directory contains the browsable SwiftUI source, Xcode project, app assets, privacy manifest and native checks for Thought Meadow. The main branch includes maintenance changes that may not yet be in an App Store release. The code is under MIT. Development was AI-assisted. No account, analytics, ads or developer server is included.

[App Store](https://apps.apple.com/us/app/thought-meadow-private-notes/id6825094170) · [Support and privacy](https://alawyadnan.github.io/thought-meadow/)

## Maintenance 1.0.3 (7) — submitted 28 October 2026

Version 1.0.3 (7) is **Waiting for Review** at Apple; submission does not mean the update is approved or live. Version 1.0.2 was the public release at this check.

This update adds a permanent backup reminder next to Export in English/Arabic and the `thought-meadow-backup.json` filename. It also applies the selected locale and direction to Settings, refreshing only its Form when direction changes so the root/editor identity is retained. The 26 existing native checks and unsigned iOS/Simulator builds passed. On iPhone 17e Simulator / iOS 26.4.1, Settings stayed open and aligned correctly in both directions; the Files export sheet saved a fictional sample without error. Physical-iPhone editor and VoiceOver checks remain pending in the interaction matrix.

Read [product principles](PRODUCT_PRINCIPLES.md) and [working guidance](AGENTS.md) before changing the experience. Preserve immediate writing, a calm usable interface, lightweight optional organization and equal Arabic/English support.

## Build

Open `Waraqa.xcodeproj` in Xcode and choose the `Waraqa` scheme. The app requires iOS 17 or later and targets iPhone. The internal name and bundle identifier retain the original development name for data compatibility. For your own signed build, select your own development team and bundle identifier.

An unsigned build can be checked from this directory with:

```sh
xcodebuild -project Waraqa.xcodeproj -scheme Waraqa -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/ThoughtMeadowBuild CODE_SIGNING_ALLOWED=NO build
```

## Native data checks on macOS

```sh
xcrun swiftc -parse-as-library -O -module-cache-path /tmp/ThoughtMeadowModuleCache Waraqa/Models.swift Waraqa/VaultCrypto.swift Waraqa/NotebookStore.swift Tests/NativeChecks.swift -o /tmp/thought-meadow-native-checks
/tmp/thought-meadow-native-checks
xcrun swiftc -parse-as-library -O -module-cache-path /tmp/ThoughtMeadowModuleCache Waraqa/Models.swift Waraqa/VaultCrypto.swift Waraqa/NotebookStore.swift Tests/ScaleChecks.swift -o /tmp/thought-meadow-scale-checks
/tmp/thought-meadow-scale-checks
```

The scale checks create 500 fictional notes and verify save/reopen, search, tag filtering, encryption/lock/unlock and encrypted-backup import into a fresh notebook. They passed on macOS on 22 October 2026. This measures the data layer; it does not measure iPhone UI frame rate or Markdown rendering latency.

## Storage and encryption

Notes are stored locally using atomic writes and iOS complete file protection. Optional notebook encryption uses AES-256-GCM with PBKDF2-SHA-256 and 600,000 iterations. A password cannot be recovered. Notes are excluded from automatic device backups: export copies regularly through Files and keep them outside the device; deleting the app can delete local notes. The app has not had an independent security audit. Sync, shared lists and subscriptions are not implemented in this release.


## Checklist and language maintenance — 24 October 2026

The preview and edit action now share a task-line parser. Indented tasks preserve their spaces/tabs, text, punctuation and line endings when the checkbox is changed. Language changes update view inputs instead of replacing the root identity, so navigation and sheet state can be retained.

```sh
xcrun swiftc -parse-as-library -O -module-cache-path /tmp/ThoughtMeadowChecklistCache Waraqa/Models.swift Waraqa/VaultCrypto.swift Waraqa/NotebookStore.swift Tests/ChecklistChecks.swift -o /tmp/thought-meadow-checklists
/tmp/thought-meadow-checklists
```

The 14 checklist checks and 26 existing native checks passed on macOS. The iOS Simulator build succeeded. After Device Hub recovered, interactive checks passed on iPhone 17 Pro Max Simulator (iOS 26.4.1): the settings sheet stayed open while switching to Arabic and back to English; three task controls rendered from top-level, space-indented and tab-indented lines; toggling the Arabic subtask preserved the raw source and remained checked after leaving and reopening the note. See [the interaction matrix](Tests/EditorInteractionChecks.md) for exact scope and the remaining physical-phone cursor, scroll, undo, software-keyboard and VoiceOver checks. TextEditor has not been replaced based on an unverified scrolling issue. These maintenance changes are included in App Store version 1.0.2, confirmed on the public listing on 25 October 2026. The interaction matrix includes the additional English-leading/Arabic-ending checklist fixture and its narrowly scoped simulator results.
