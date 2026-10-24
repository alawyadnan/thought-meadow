import Foundation

@main struct ChecklistChecks {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw NSError(domain: "ChecklistChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        print("PASS: " + message)
    }

    @MainActor static func main() async throws {
        let cases: [(String, String, String)] = [
            ("- [ ] Buy milk", "- [x] Buy milk", "- [ ] Buy milk"),
            ("  - [ ] مهمة (taskName) ✅", "  - [x] مهمة (taskName) ✅", "  - [ ] مهمة (taskName) ✅"),
            ("\t- [X] call(foo)  ", "\t- [X] call(foo)  ", "\t- [ ] call(foo)  "),
            (" \t - [ ] 👩🏽‍💻 cafe\u{301} العربية", " \t - [x] 👩🏽‍💻 cafe\u{301} العربية", " \t - [ ] 👩🏽‍💻 cafe\u{301} العربية"),
            ("- [ ] ", "- [x] ", "- [ ] "),
            ("\t  - [x] العربية English (x)\r", "\t  - [x] العربية English (x)\r", "\t  - [ ] العربية English (x)\r")
        ]
        for (index, item) in cases.enumerated() {
            guard let task = MarkdownTaskLine(item.0) else { throw NSError(domain: "ChecklistChecks", code: 2) }
            try check(task.settingChecked(true) == item.1 && task.settingChecked(false) == item.2,
                      "Task case \(index + 1) preserves indentation, Unicode, punctuation and trailing whitespace")
        }
        let nonTasks = ["", "  ", "- [ ]", "- [y] text", "- [] text", "prefix - [ ] text", "- [ ]text", "* [ ] text", "\u{2003}- [ ] text"]
        try check(nonTasks.allSatisfy { MarkdownTaskLine($0) == nil }, "Plain text and malformed or unsupported markers are not interactive tasks")
        let deepIndent = String(repeating: " ", count: 50_000)
        let deepTask = MarkdownTaskLine(deepIndent + "- [ ] preserved")!
        try check(deepTask.indentationColumns == 24 && deepTask.settingChecked(true) == deepIndent + "- [x] preserved", "Deep indentation is bounded for layout and preserved in source")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("thought-meadow-checklists-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NotebookStore(directory: directory)
        let id = store.addNote(view: "all")!
        let original = "Heading\r\n  - [ ] مهمة (taskName) ✅\r\n\t- [X] child 👩🏽‍💻  \r\n- [ ] final\n"
        let expected = "Heading\r\n  - [x] مهمة (taskName) ✅\r\n\t- [ ] child 👩🏽‍💻  \r\n- [ ] final\n"
        store.update(id) { $0.body = original }
        store.setTaskChecked(id, line: 1, checked: true)
        store.setTaskChecked(id, line: 2, checked: false)
        try check(store.note(id)?.body == expected, "Store toggles nested tasks without changing other lines or CRLF/newline endings")
        let before = store.note(id)
        for index in [-1, 0, 100] { store.setTaskChecked(id, line: index, checked: true) }
        store.setTaskChecked(id, line: 1, checked: true)
        try check(store.note(id) == before, "Invalid indices, ordinary lines and unchanged checkbox state do not modify a note")
        try store.save()
        let reopened = NotebookStore(directory: directory)
        try check(reopened.note(id)?.body == expected, "Nested checklist edits survive saving and reopening")
        reopened.setStatus(id, "trash")
        let trashed = reopened.note(id)
        reopened.setTaskChecked(id, line: 1, checked: false)
        try check(reopened.note(id) == trashed, "Trash remains read-only for task toggles")
        reopened.setStatus(id, "active")
        try await reopened.enableEncryption(password: "Checklist-test-password-2026")
        reopened.setTaskChecked(id, line: 3, checked: true)
        try reopened.save()
        let encryptedExpected = expected.replacingOccurrences(of: "- [ ] final", with: "- [x] final")
        reopened.lock()
        reopened.setTaskChecked(id, line: 1, checked: false)
        try check(reopened.locked && reopened.notebook.notes.isEmpty, "Task actions cannot alter a locked notebook")
        let encrypted = NotebookStore(directory: directory)
        try await encrypted.unlock(password: "Checklist-test-password-2026")
        try check(encrypted.note(id)?.body == encryptedExpected, "Encrypted checklist edits survive lock, reopen and unlock")
        print("All checklist checks passed.")
    }
}
