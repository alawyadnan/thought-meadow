import Foundation

@main struct FeedbackChecks {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw NSError(domain:"FeedbackChecks",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
        print("PASS: " + message)
    }

    @MainActor static func main() async throws {
        let previousLanguage = UserDefaults.standard.string(forKey:"appLanguage")
        defer {
            if let previousLanguage { UserDefaults.standard.set(previousLanguage,forKey:"appLanguage") }
            else { UserDefaults.standard.removeObject(forKey:"appLanguage") }
        }
        UserDefaults.standard.set("en",forKey:"appLanguage")

        let marked = Note(title:"مُلَاحَظَات",body:"مَدرَسة جميلة",tags:["تَعَلُّم"])
        let plain = Note(title:"ملاحظات",body:"مدرسة جميلة",tags:["تعلم"])
        let book = Notebook(notes:[marked,plain,Note(title:"Other",body:"Café 🌿")])
        try check(book.filtered(view:"all",query:"ملاحظات").count == 2,"Unmarked Arabic query matches marked and unmarked titles")
        try check(book.filtered(view:"all",query:"مُلَاحَظَات").count == 2,"Marked Arabic query matches both titles")
        try check(book.filtered(view:"all",query:"مدرسة").count == 2,"Arabic full-body search ignores harakat")
        try check(book.filtered(view:"all",query:"تَعَلُّم").count == 2,"Arabic tag text matches with shadda and vowels")
        let canonical = Notebook(notes:[Note(body:"أفكار أفكار إلهام آمال هٰذا")])
        try check(["افكار","إفْكَار","الهام","امال","هذا"].allSatisfy { canonical.filtered(view:"all",query:$0).count == 1 },"Alef variants, canonical forms and superscript alef remain searchable")
        try check(book.filtered(view:"all",query:"CAFE").count == 1 && book.filtered(view:"all",query:"🌿").count == 1 && book.filtered(view:"all",query:"مختلف").isEmpty,"Latin accent/case, emoji and nonmatches are preserved")
        try check(book.notes[0] == marked && book.notes[1] == plain,"Search leaves stored Arabic content unchanged")

        let suite = "ThoughtMeadow.FeedbackChecks." + UUID().uuidString
        let defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let key = BackupExportHistory.defaultsKey
        let date = Date(timeIntervalSince1970:1_793_681_400)
        let url = URL(fileURLWithPath:"/tmp/fictional-export.json")
        let cancelled: Result<URL,Error> = .failure(NSError(domain:NSCocoaErrorDomain,code:NSUserCancelledError))
        BackupExportHistory.record(cancelled,at:date,defaults:defaults)
        try check(defaults.object(forKey:key) == nil,"Cancelled export does not invent a completed backup")
        BackupExportHistory.record(.success(url),at:date,defaults:defaults)
        try check(defaults.double(forKey:key) == date.timeIntervalSince1970,"Successful full-export completion persists only its timestamp")
        BackupExportHistory.record(.failure(NSError(domain:"DiskFull",code:1)),at:date.addingTimeInterval(86400),defaults:defaults)
        try check(defaults.double(forKey:key) == date.timeIntervalSince1970,"Failed export preserves the previous successful timestamp")
        try check(BackupExportHistory.daysSince(0,now:date) == nil && BackupExportHistory.daysSince(.nan,now:date) == nil,"Untracked and invalid export history are not presented as a backup")
        var calendar = Calendar(identifier:.gregorian)
        calendar.timeZone = TimeZone(identifier:"America/Los_Angeles")!
        let formatter = ISO8601DateFormatter()
        let beforeMidnight = formatter.date(from:"2026-11-01T06:55:00Z")!
        let afterMidnight = formatter.date(from:"2026-11-01T07:05:00Z")!
        let afterDST = formatter.date(from:"2026-11-02T08:05:00Z")!
        try check(BackupExportHistory.daysSince(beforeMidnight.timeIntervalSince1970,now:afterMidnight,calendar:calendar) == 1 && BackupExportHistory.daysSince(beforeMidnight.timeIntervalSince1970,now:afterDST,calendar:calendar) == 2,"Export age follows local calendar days across midnight and DST")
        try check(BackupExportHistory.daysSince(afterDST.timeIntervalSince1970,now:beforeMidnight,calendar:calendar) == 0,"Clock changes never display a negative export age")
        try check(BackupExportHistory.label(0,now:date).contains("on this device") && BackupExportHistory.label(date.timeIntervalSince1970,now:date).contains("today"),"English history distinguishes unknown from successful export today")
        UserDefaults.standard.set("ar",forKey:"appLanguage")
        try check(BackupExportHistory.label(0,now:date).contains("هذا الجهاز") && BackupExportHistory.label(date.timeIntervalSince1970,now:date).contains("اليوم"),"Arabic export status is localized")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("thought-meadow-feedback-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store = NotebookStore(directory:root)
        let existing = store.notebook
        let reused = existing.folders[0]
        let newFolder = NoteFolder(name:"Feedback fixture folder")
        let incoming = Notebook(folders:[NoteFolder(id:"reuse",name:reused.name),newFolder],notes:[
            Note(title:"Active fixture",body:"مُلَاحَظَات",folder:"reuse"),
            Note(title:"Archived fixture",folder:newFolder.id,status:"archive"),
            Note(title:"Trash fixture",status:"trash")
        ])
        let summary = try store.merge(incoming)
        try check(summary.notesAdded == 3 && summary.foldersAdded == 1,"Import result counts actual added notes and only newly created folders")
        let reopened = NotebookStore(directory:root)
        try check(existing.notes.allSatisfy { old in reopened.notebook.notes.contains(old) } && reopened.notebook.notes.count == existing.notes.count + 3,"Successful import summary corresponds to persisted data and preserves existing notes")
        try check(reopened.notebook.filtered(view:"archive",query:"Archived fixture").count == 1 && reopened.notebook.filtered(view:"trash",query:"Trash fixture").count == 1,"Imported Archive and Trash statuses are retained")
        let repeated = try reopened.merge(incoming)
        try check(repeated.notesAdded == 3 && repeated.foldersAdded == 0,"Repeated import reports fresh note copies without inventing new folders")
        var invalid = incoming; invalid.notes[1].id = invalid.notes[0].id
        let beforeFailure = reopened.notebook.notes
        do { _ = try reopened.merge(invalid); throw NSError(domain:"FeedbackChecks",code:2) }
        catch WaraqaError.invalidBackup { print("PASS: Invalid import produces no success summary") }
        try check(reopened.notebook.notes == beforeFailure,"Failed import leaves the previous notebook intact")
        print("All feedback checks passed.")
    }
}
