import Foundation
import CryptoKit

@main struct NativeChecks {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw NSError(domain:"NativeChecks",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
        print("PASS: " + message)
    }
    @MainActor static func main() async throws {
        let previousLanguage = UserDefaults.standard.string(forKey:"appLanguage")
        defer {
            if let previousLanguage { UserDefaults.standard.set(previousLanguage,forKey:"appLanguage") }
            else { UserDefaults.standard.removeObject(forKey:"appLanguage") }
        }
        UserDefaults.standard.set("en",forKey:"appLanguage")
        let english = Notebook.welcome
        try check(english.filtered(view:"all",query:"thoughts").count > 0 && L("ورقة") == "Thought Meadow","English onboarding and brand")
        UserDefaults.standard.set("ar",forKey:"appLanguage")
        let sample = Notebook.welcome
        try check(L("ورقة") == "مرج الأفكار" && !AppLanguage.locale.identifier.hasPrefix("en"),"Arabic locale and brand")
        try check(sample.filtered(view:"all",query:"افكارك").count > 0,"Arabic alef search")
        try check(sample.filtered(view:"pinned",query:"").count == 1,"Pinned filtering")
        let merged = try sample.merging(sample)
        try check(merged.notes.count == sample.notes.count * 2 && Set(merged.notes.map(\.id)).count == merged.notes.count,"Import preserves original records and generates unique IDs")
        var invalid = sample; invalid.notes[1].id = invalid.notes[0].id
        do { _ = try invalid.validated(); throw NSError(domain:"Checks",code:2) } catch WaraqaError.invalidBackup { print("PASS: Duplicate backup rejected") }
        let salt = VaultCrypto.newSalt(), key = try VaultCrypto.derive(password:"Waraqa-native-test-2026",salt:salt)
        let a = try VaultCrypto.seal(sample,key:key,salt:salt), b = try VaultCrypto.seal(sample,key:key,salt:salt)
        try check(a.iv != b.iv,"Fresh encryption nonce")
        let decoded = try VaultCrypto.open(a,key:key)
        try check(decoded.notes == sample.notes,"Encrypted data roundtrip")
        let wrong = try VaultCrypto.derive(password:"wrong-test-password",salt:salt)
        do { _ = try VaultCrypto.open(a,key:wrong); throw NSError(domain:"Checks",code:3) } catch WaraqaError.wrongPassword { print("PASS: Incorrect password rejected") }
        var altered = a; var raw = Data(base64Encoded:altered.payload!)!; raw[0] ^= 1; altered.payload = raw.base64EncodedString()
        do { _ = try VaultCrypto.open(altered,key:key); throw NSError(domain:"Checks",code:4) } catch WaraqaError.wrongPassword { print("PASS: Ciphertext tampering rejected") }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("waraqa-test-" + UUID().uuidString,isDirectory:true)
        defer { try? FileManager.default.removeItem(at:temporary) }
        let store = NotebookStore(directory:temporary)
        let id = store.addNote(view:"all")!
        store.update(id) { $0.title = "تجربة حفظ"; $0.body = "نص لا ينبغي أن يضيع" }
        try store.save()
        let reopened = NotebookStore(directory:temporary)
        try check(reopened.note(id)?.body == "نص لا ينبغي أن يضيع","Atomic save survives reopening")
        try await reopened.enableEncryption(password:"Waraqa-native-test-2026")
        try check(!FileManager.default.fileExists(atPath:reopened.previousURL.path),"Encryption drops clear recovery copy")
        let bytes = try Data(contentsOf:reopened.currentURL)
        try check(!String(decoding:bytes,as:UTF8.self).contains("نص لا ينبغي أن يضيع"),"Stored encrypted vault contains no note plaintext")
        reopened.lock()
        try check(reopened.locked && reopened.notebook.notes.isEmpty,"Lock clears in-memory notebook")
        let locked = NotebookStore(directory:temporary)
        try check(locked.locked,"Encrypted vault starts locked")
        try check(locked.addNote(view:"all") == nil,"Locked space rejects new notes")
        do { _ = try locked.backup(); throw NSError(domain:"Checks",code:5) } catch WaraqaError.spaceLocked { print("PASS: Locked backup cannot export an empty clear vault") }
        do { try locked.merge(sample); throw NSError(domain:"Checks",code:6) } catch WaraqaError.spaceLocked { print("PASS: Locked space rejects imports") }
        let opening = Task { try await locked.unlock(password:"Waraqa-native-test-2026") }
        while !locked.unlocking { await Task.yield() }
        locked.lock()
        do { try await opening.value; throw NSError(domain:"Checks",code:7) } catch WaraqaError.unlockCancelled { print("PASS: Background lock cancels pending password unlock") }
        try check(locked.locked && locked.notebook.notes.isEmpty,"Cancelled unlock keeps contents locked")
        try await locked.unlock(password:"Waraqa-native-test-2026")
        try check(locked.note(id)?.title == "تجربة حفظ","Encrypted vault unlock restores data")
        let exported = try JSONDecoder().decode(VaultEnvelope.self,from:locked.backup())
        try check(exported.encrypted && exported.data == nil,"Backup preserves encryption")
        let large = Notebook(notes:(0..<56).map { index in Note(title:"Large fixture \(index)",body:String(repeating:"a",count:190_000)) })
        try locked.merge(large)
        let largeBackup = try locked.backup()
        try check(largeBackup.count > 10_000_000,"Fixture covers encrypted exports larger than 10 MB")
        let backupURL = temporary.appendingPathComponent("large-backup.json")
        try largeBackup.write(to:backupURL)
        let imported = try locked.readImport(backupURL)
        let importedBook = try await locked.decodeImport(imported,password:"Waraqa-native-test-2026")
        try check(importedBook.notes.count == locked.notebook.notes.count,"Large encrypted backup can be imported again")
        let oldIDs = locked.notebook.notes.map(\.id)
        do { try locked.merge(large); throw NSError(domain:"Checks",code:8) } catch WaraqaError.storageLimit { print("PASS: Oversized import rejected") }
        try check(locked.notebook.notes.map(\.id) == oldIDs,"Rejected import preserves the existing notebook")
        if CommandLine.arguments.count > 2 {
            let web = try JSONDecoder().decode(VaultEnvelope.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
            let webKey = try VaultCrypto.derive(password:"Cross-platform-test-2026",salt:Data(base64Encoded:web.salt!)!)
            let notebook = try VaultCrypto.open(web,key:webKey)
            try check(notebook.notes.count == 6,"Native decrypts web backup")
            try JSONEncoder().encode(VaultCrypto.seal(notebook,key:webKey,salt:Data(base64Encoded:web.salt!)!)).write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
        }
        print("All native checks passed.")
    }
}
