import Foundation

// Storage and search checks for a 500-note notebook. This does not measure UI frame rate.
@main struct ScaleChecks {
    static func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
        guard value() else { throw NSError(domain: "ScaleChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        print("PASS: \(message)")
    }

    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("thought-meadow-scale-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = NotebookStore(directory: root.appendingPathComponent("original"))
        let sampleCount = store.notebook.notes.count
        let body = String(repeating: "A thought and an idea. فكرة وملاحظة.\n", count: 30)
        var expected: [String: String] = [:]
        let start = Date()
        for index in 0..<500 {
            guard let id = store.addNote(view: "all") else { throw WaraqaError.noNote }
            let title = "Scale note \(index) ملاحظة"
            store.update(id) {
                $0.title = title
                $0.body = body + "unique-scale-token-\(index)-end"
                $0.tags = ["scale-fixture"]
                $0.pinned = index % 50 == 0
            }
            expected[id] = title
        }
        try store.save()
        try require(store.notebook.notes.count == sampleCount + 500, "500 new notes saved")
        let reopened = NotebookStore(directory: store.directory)
        try require(reopened.loaded && reopened.error == nil, "500-note notebook reopens without a load error")
        try require(expected.allSatisfy { reopened.note($0.key)?.title == $0.value && reopened.note($0.key)?.body.hasPrefix(body) == true }, "All 500 note titles and bodies survive reopening")
        let searchStart = Date()
        let found = reopened.notebook.filtered(view: "all", query: "unique-scale-token-299-end")
        let searchMS = Date().timeIntervalSince(searchStart) * 1000
        try require(found.count == 1 && found[0].title == "Scale note 299 ملاحظة", "Search finds the exact fixture among 500 notes")
        try require(reopened.notebook.filtered(view: "tag:scale-fixture", query: "").count == 500, "Tag filtering includes all 500 notes")
        try await reopened.enableEncryption(password: "Scale-fixture-password-2026")
        reopened.lock()
        let locked = NotebookStore(directory: store.directory)
        try require(locked.locked && locked.notebook.notes.isEmpty, "500-note encrypted notebook starts locked")
        try await locked.unlock(password: "Scale-fixture-password-2026")
        try require(expected.allSatisfy { locked.note($0.key)?.title == $0.value }, "All 500 records survive encrypt, lock and unlock")
        let bytes = try locked.backup()
        let exportURL = root.appendingPathComponent("export.json")
        try bytes.write(to: exportURL)
        let destination = NotebookStore(directory: root.appendingPathComponent("imported"))
        let decoded = try await destination.decodeImport(destination.readImport(exportURL), password: "Scale-fixture-password-2026")
        try destination.merge(decoded)
        let imported = NotebookStore(directory: destination.directory)
        let fixtureNotes = imported.notebook.notes.filter { $0.tags.contains("scale-fixture") }
        try require(fixtureNotes.count == 500 && Set(fixtureNotes.map(\.title)) == Set(expected.values), "Encrypted backup imports all 500 fixture records into a fresh notebook")
        try require(fixtureNotes.allSatisfy { $0.body.hasPrefix(body) }, "Imported bodies retain their full fixture content")
        print(String(format: "INFO: macOS data-layer fixture completed in %.2f s; one full-body search %.1f ms; backup %d bytes", Date().timeIntervalSince(start), searchMS, bytes.count))
        print("All scale checks passed. iPhone UI responsiveness was not measured.")
    }
}
