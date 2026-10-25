# Editor interaction checks — 24 October 2026

Use fictional notes only. Record the device, iOS version, app version and input method. A passing storage test does not establish cursor, undo, VoiceOver or frame-rate behavior.

## Verified on iPhone 17 Pro Max Simulator, iOS 26.4.1

- Open Settings, change English/device language to Arabic and back to English. The same settings sheet remains presented and its labels update in both directions.
- Create a body-only note containing English-leading and Arabic-leading paragraphs, a top-level task, a space-indented Arabic task, and a tab-indented checked task with accented text and emoji.
- Preview exposes three separate task buttons and their completed/not-completed accessibility values. Toggling the space-indented task changes only its checkbox state. Returning to Write preserves indentation, the other task states and mixed-script content.
- Return to the list and reopen the note: the selected nested task remains completed. This is an in-app reopen check; cold-start persistence is separately covered by native data checks.

The 24 October simulator checks used maintenance source with the existing 1.0.1 (5) development metadata. That source was subsequently shipped as 1.0.2 (6); the public App Store page was confirmed to show version 1.0.2 on 25 October. Input was supplied through Device Hub with hardware-keyboard capture. This is not a physical-phone or on-screen-keyboard result.

## Physical-device matrix still pending

1. **Long note, cursor and scroll:** use a long fictional note with several screens of paragraphs. Place the insertion point in its middle, type a unique marker with the on-screen keyboard open, and record the visible paragraph and selection. Change device/app language through the supported route, resume, and compare content, selection, scroll offset and keyboard state. App-language settings are currently on the root screen, so leaving an editor to reach them is a navigation change; do not equate editor reconstruction with an in-place language update.
2. **Undo across a language update:** type separate English and Arabic edits in the middle of a note. Verify baseline Undo/Redo, then repeat around the language transition. Check exact text after each undo and redo, including any autocorrection. If the OS restarts the app for its language change, record that separately from a live environment update.
3. **Paragraph direction:** use English-leading and Arabic-leading paragraphs containing the other script, numbers, parentheses, punctuation and emoji. In both Write and Preview, check wrapping, selection, caret movement and logical content independently of the app chrome direction.
4. **Keyboard and correction:** switch Arabic/English keyboards mid-note. Check insertion, selection replacement, autocorrection/spellcheck and undo without lost or duplicated text.
5. **VoiceOver:** with VoiceOver enabled on the test iPhone, read the mixed-script paragraphs and task controls in both app languages. Check spoken order, task labels/state and focus after toggling. Accessibility-tree labels alone do not establish spoken reading order.
6. **Long-note scrolling:** scroll both within and around TextEditor with the software keyboard open. Verify interactive keyboard dismissal, reaching the beginning/end and editing after a scroll, including smaller screens and larger Dynamic Type sizes.

TextEditor and the encryption implementation remain unchanged in this maintenance patch. Do not report the pending cases as passing or call the application independently security-audited.

## Focused mixed-script fixture — 25 October 2026

Added after the reviews by imsnk81 and cocoabuilder. Copy the following fictional body into a fresh note:

```text
English starts here and ends بالعربية
- [ ] Review plan (v2) ثم راجع العربية
  - [ ] Ship build 6 ثم انتهى
العربية أولًا ثم English (123).
- [x] English completed ثم اكتمل
```

On iPhone 17 Pro Max Simulator, iOS 26.4.1, with English app chrome and the maintenance source above, Preview exposed three task controls. Toggling line 2 (the indented Ship task; zero-based line index) changed only its checkbox state. The raw body matched the expected text, including spaces and the other task states. After returning to the list and reopening the note, the Ship task remained completed and the other two states remained unchanged. Input used Device Hub hardware-keyboard capture. This verifies this concrete rendering/toggle/reopen path, not physical-phone caret, spoken order, or a live language transition.

For the physical-phone pass, record the selection/caret anchor, first visible paragraph/scroll position, keyboard state and the VoiceOver utterances/focus sequence before and after the supported language transition. Include this English-leading/Arabic-ending task and an Arabic-leading paragraph. Record whether any language/direction announcement occurs and whether the text is read in the expected logical order; do not mark the check as passing from accessibility labels alone or require a particular announcement without observing the actual iOS behaviour. Keep OS-triggered app relaunches separate from a live environment update. These physical-phone checks remain pending.

## Directional VoiceOver and immediate-focus cases — 25 October 2026

Following cocoabuilder's additional review, run each transition independently. A result for one direction does not establish the reverse direction, and spoken order alone does not establish useful focus placement.

| Starting surface | Language transition | Input state to record | Physical-phone result |
| --- | --- | --- | --- |
| Write | English → Arabic | Caret/selection and on-screen keyboard before leaving the editor | Pending |
| Write | Arabic → English | Caret/selection and on-screen keyboard before leaving the editor | Pending |
| Preview | English → Arabic | Focused paragraph or task and its checked state | Pending |
| Preview | Arabic → English | Focused paragraph or task and its checked state | Pending |

For each case, record:

1. The focused element's role, label and logical location before the transition, plus the visible paragraph and keyboard state where relevant.
2. The first VoiceOver focus target immediately after the transition, before any swipe, tap or other action that could repair or move focus. Record whether it returns to the same context, moves to the top, or lands in app chrome. A matching spoken transcript alone is not a pass.
3. The actual announcement/utterance sequence and subsequent focus order separately. Record observed language/direction announcements, including their absence; do not assume the two transition directions behave alike.
4. Focus and editor state when returning to the note through the supported navigation route. The current app-language control is in root Settings: record the immediate post-switch target there separately from the editor target after navigating back. Do not describe leaving and reopening the editor as an in-place switch with the keyboard continuously open. Record any OS-triggered relaunch separately.

Use the same mixed-script fixture in all four cases and record device, iOS/app version, VoiceOver language/voice settings and the exact route used. All four physical-phone results remain pending; no new runtime defect or verified physical-phone result is established by adding this matrix.
