# Editor interaction checks — 24 October 2026

Use fictional notes only. Record the device, iOS version, app version and input method. A passing storage test does not establish cursor, undo, VoiceOver or frame-rate behavior.

## Verified on iPhone 17 Pro Max Simulator, iOS 26.4.1

- Open Settings, change English/device language to Arabic and back to English. The same settings sheet remains presented and its labels update in both directions.
- Create a body-only note containing English-leading and Arabic-leading paragraphs, a top-level task, a space-indented Arabic task, and a tab-indented checked task with accented text and emoji.
- Preview exposes three separate task buttons and their completed/not-completed accessibility values. Toggling the space-indented task changes only its checkbox state. Returning to Write preserves indentation, the other task states and mixed-script content.
- Return to the list and reopen the note: the selected nested task remains completed. This is an in-app reopen check; cold-start persistence is separately covered by native data checks.

Tested maintenance source used the existing 1.0.1 (5) development metadata; the store build does not contain these source changes yet. Input was supplied through Device Hub with hardware-keyboard capture. This is not a physical-phone or on-screen-keyboard result.

## Physical-device matrix still pending

1. **Long note, cursor and scroll:** use a long fictional note with several screens of paragraphs. Place the insertion point in its middle, type a unique marker with the on-screen keyboard open, and record the visible paragraph and selection. Change device/app language through the supported route, resume, and compare content, selection, scroll offset and keyboard state. App-language settings are currently on the root screen, so leaving an editor to reach them is a navigation change; do not equate editor reconstruction with an in-place language update.
2. **Undo across a language update:** type separate English and Arabic edits in the middle of a note. Verify baseline Undo/Redo, then repeat around the language transition. Check exact text after each undo and redo, including any autocorrection. If the OS restarts the app for its language change, record that separately from a live environment update.
3. **Paragraph direction:** use English-leading and Arabic-leading paragraphs containing the other script, numbers, parentheses, punctuation and emoji. In both Write and Preview, check wrapping, selection, caret movement and logical content independently of the app chrome direction.
4. **Keyboard and correction:** switch Arabic/English keyboards mid-note. Check insertion, selection replacement, autocorrection/spellcheck and undo without lost or duplicated text.
5. **VoiceOver:** with VoiceOver enabled on the test iPhone, read the mixed-script paragraphs and task controls in both app languages. Check spoken order, task labels/state and focus after toggling. Accessibility-tree labels alone do not establish spoken reading order.
6. **Long-note scrolling:** scroll both within and around TextEditor with the software keyboard open. Verify interactive keyboard dismissal, reaching the beginning/end and editing after a scroll, including smaller screens and larger Dynamic Type sizes.

TextEditor and the encryption implementation remain unchanged in this maintenance patch. Do not report the pending cases as passing or call the application independently security-audited.
