import Foundation
import SwiftUI
import Combine
import CryptoKit

@MainActor final class NotebookStore: ObservableObject {
    @Published private(set) var notebook = Notebook()
    @Published private(set) var locked = false
    @Published private(set) var loaded = false
    @Published private(set) var unlocking = false
    @Published private var saveMessage = "نجهّز مساحة لأفكارك…"
    var saveLabel: String { L(saveMessage) }
    var saveFailed: Bool { saveMessage.hasPrefix("لم يكتمل") }
    @Published var error: String?
    private var key: SymmetricKey?
    private var salt: Data?
    private var pending: Task<Void,Never>?
    private var envelope: VaultEnvelope?
    private var dirty = false
    private var lockRevision = 0
    private(set) var lastActivity = Date()
    let directory: URL
    var isEncrypted: Bool { key != nil || envelope?.encrypted == true }
    var currentURL: URL { directory.appendingPathComponent("vault.json") }
    var previousURL: URL { directory.appendingPathComponent("previous.json") }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Waraqa",isDirectory:true)
        load()
    }
    func load() {
        do {
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            var dir = directory, values = URLResourceValues(); values.isExcludedFromBackup = true; try dir.setResourceValues(values)
            if FileManager.default.fileExists(atPath:currentURL.path) {
                let bytes = try Data(contentsOf:currentURL)
                guard bytes.count <= 16_000_000 else { throw WaraqaError.tooLarge }
                envelope = try JSONDecoder().decode(VaultEnvelope.self,from:bytes).validated()
                if envelope!.encrypted { locked = true; loaded = true; saveMessage = "المساحة مقفلة"; return }
                notebook = try envelope!.data!.validated()
            } else { notebook = .welcome; dirty = true; try save() }
            loaded = true; locked = false; saveMessage = "محفوظ على جهازك"
        } catch { self.error = L("تعذّر فتح المساحة. لم نستبدل بياناتك. ") + error.localizedDescription }
    }
    func activity() { lastActivity = Date() }
    func note(_ id: String) -> Note? { notebook.notes.first { $0.id == id } }
    func update(_ id: String, _ transform: (inout Note) -> Void) {
        guard !locked, let index = notebook.notes.firstIndex(where: { $0.id == id }), notebook.notes[index].status != "trash" else { return }
        transform(&notebook.notes[index]); notebook.notes[index].updated = Date().timeIntervalSince1970 * 1000; changed()
    }
    func setTaskChecked(_ id: String, line index: Int, checked: Bool) {
        guard let note = note(id), note.status != "trash", !locked else { return }
        var lines = note.body.components(separatedBy: "\n")
        guard lines.indices.contains(index), let task = MarkdownTaskLine(lines[index]), task.isChecked != checked else { return }
        lines[index] = task.settingChecked(checked)
        update(id) { $0.body = lines.joined(separator: "\n") }
    }
    func changed() {
        activity(); dirty = true; saveMessage = "جارٍ الحفظ…"; pending?.cancel()
        pending = Task { [weak self] in
            do { try await Task.sleep(for:.milliseconds(350)); try Task.checkCancellation(); try self?.save() }
            catch is CancellationError {} catch { self?.reportSave(error) }
        }
    }
    private func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to:url,options:[.atomic,.completeFileProtection])
        #else
        try data.write(to:url,options:.atomic)
        #endif
    }
    func save() throws {
        pending?.cancel(); pending = nil; guard dirty else { return }
        let next = try key.map { try VaultCrypto.seal(notebook,key:$0,salt:salt!) } ?? .clear(notebook.validated())
        let bytes = try JSONEncoder().encode(next)
        guard bytes.count <= 16_000_000 else { throw WaraqaError.storageLimit }
        if FileManager.default.fileExists(atPath:currentURL.path) { try write(Data(contentsOf:currentURL),to:previousURL) }
        try write(bytes,to:currentURL); envelope = next; dirty = false; saveMessage = "محفوظ على جهازك"
    }
    func flush() { do { try save() } catch { reportSave(error) } }
    private func reportSave(_ error: Error) { saveMessage = "لم يكتمل الحفظ — صدّر نسخة الآن"; self.error = error.localizedDescription }
    func addNote(view: String) -> String? {
        guard loaded, !locked else { return nil }
        guard notebook.notes.count < 10_000 else { error = L("وصلت للحد الأقصى للملاحظات."); return nil }
        var n = Note(); if view.hasPrefix("folder:") { n.folder = String(view.dropFirst(7)) }; if view.hasPrefix("tag:") { n.tags = [String(view.dropFirst(4))] }; if view == "pinned" { n.pinned = true }
        notebook.notes.insert(n,at:0); changed(); return n.id
    }
    func setStatus(_ id: String, _ status: String) { guard let i = notebook.notes.firstIndex(where: { $0.id == id }) else { return }; notebook.notes[i].status = status; notebook.notes[i].updated = Date().timeIntervalSince1970 * 1000; changed() }
    func deletePermanently(_ id: String) { notebook.notes.removeAll { $0.id == id }; changed() }
    func removeSamples() { for i in notebook.notes.indices where notebook.notes[i].sample { notebook.notes[i].status = "trash" }; changed() }
    func addFolder(_ name: String) throws {
        let name = name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80, notebook.folders.count < 500, !notebook.folders.contains(where: { $0.name == name }) else { throw WaraqaError.invalidBackup }
        notebook.folders.append(NoteFolder(name:name)); changed()
    }
    func removeFolder(_ id: String) { notebook.folders.removeAll { $0.id == id }; for i in notebook.notes.indices where notebook.notes[i].folder == id { notebook.notes[i].folder = "" }; changed() }
    func lock() {
        lockRevision += 1
        guard key != nil else { return }; do { try save(); notebook = Notebook(); key = nil; salt = nil; locked = true; saveMessage = "المساحة مقفلة" } catch { reportSave(error) }
    }
    func unlock(password: String) async throws {
        guard locked, !unlocking else { throw WaraqaError.unlockCancelled }
        unlocking = true
        defer { unlocking = false }
        let revision = lockRevision
        guard let envelope, let salt = envelope.salt.flatMap({ Data(base64Encoded:$0) }) else { throw WaraqaError.invalidBackup }
        let key = try await Task.detached { try VaultCrypto.derive(password:password,salt:salt) }.value
        guard revision == lockRevision else { throw WaraqaError.unlockCancelled }
        let next = try VaultCrypto.open(envelope,key:key); self.key = key; self.salt = salt; notebook = next; locked = false; loaded = true; saveMessage = "محفوظ على جهازك"; activity()
    }
    func enableEncryption(password: String) async throws {
        guard password.count >= 12 else { throw WaraqaError.unsupportedEncryption }; try save()
        let salt = VaultCrypto.newSalt(), key = try await Task.detached { try VaultCrypto.derive(password:password,salt:salt) }.value
        let next = try VaultCrypto.seal(notebook,key:key,salt:salt)
        let bytes = try JSONEncoder().encode(next)
        guard bytes.count <= 16_000_000 else { throw WaraqaError.storageLimit }
        // Drop a clear recovery copy before committing encryption. Failure never silently discards the active vault.
        if FileManager.default.fileExists(atPath:previousURL.path) { try FileManager.default.removeItem(at:previousURL) }
        try write(bytes,to:currentURL); self.key = key; self.salt = salt; envelope = next; dirty = false; saveMessage = "محفوظ على جهازك"
    }
    func backup() throws -> Data {
        guard loaded, !locked else { throw WaraqaError.spaceLocked }
        let snapshot = try notebook.validated()
        let next = try key.map { try VaultCrypto.seal(snapshot,key:$0,salt:salt!) } ?? .clear(snapshot)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; return try encoder.encode(next)
    }
    func rawRecovery() throws -> Data { try Data(contentsOf:currentURL) }
    func restorePrevious() throws {
        guard FileManager.default.fileExists(atPath:previousURL.path) else { throw WaraqaError.noPrevious }
        let bytes = try Data(contentsOf:previousURL); _ = try JSONDecoder().decode(VaultEnvelope.self,from:bytes).validated()
        try write(bytes,to:currentURL); key = nil; salt = nil; dirty = false; notebook = Notebook(); error = nil; loaded = false; load()
    }
    func readImport(_ url: URL) throws -> VaultEnvelope {
        guard let stream = InputStream(url:url) else { throw WaraqaError.invalidBackup }; stream.open(); defer { stream.close() }
        var bytes = Data(); let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity:8192); defer { buffer.deallocate() }
        while stream.hasBytesAvailable { let count = stream.read(buffer,maxLength:8192); if count < 0 { throw stream.streamError ?? WaraqaError.invalidBackup }; if count == 0 { break }; bytes.append(buffer,count:count); if bytes.count > 24_000_000 { throw WaraqaError.tooLarge } }
        if ["md","txt"].contains(url.pathExtension.lowercased()) { guard let body = String(data:bytes,encoding:.utf8), body.count <= 200_000 else { throw WaraqaError.tooLarge }; return .clear(Notebook(notes:[Note(title:String(url.deletingPathExtension().lastPathComponent.prefix(300)),body:body)])) }
        return try JSONDecoder().decode(VaultEnvelope.self,from:bytes).validated()
    }
    func decodeImport(_ envelope: VaultEnvelope, password: String) async throws -> Notebook {
        if !envelope.encrypted { return try envelope.data!.validated() }
        guard let salt = envelope.salt.flatMap({ Data(base64Encoded:$0) }) else { throw WaraqaError.invalidBackup }
        let key = try await Task.detached { try VaultCrypto.derive(password:password,salt:salt) }.value
        return try VaultCrypto.open(envelope,key:key)
    }
    func merge(_ incoming: Notebook) throws {
        guard loaded, !locked else { throw WaraqaError.spaceLocked }
        let candidate = try notebook.merging(incoming)
        let next = try key.map { try VaultCrypto.seal(candidate,key:$0,salt:salt!) } ?? .clear(candidate)
        guard try JSONEncoder().encode(next).count <= 16_000_000 else { throw WaraqaError.storageLimit }
        let original = notebook, wasDirty = dirty
        notebook = candidate; dirty = true
        do { try save(); activity() }
        catch { notebook = original; dirty = wasDirty; if wasDirty { changed() }; throw error }
    }
}
