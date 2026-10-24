import Foundation

struct MarkdownTaskLine {
    let indentation: String
    let text: String
    let isChecked: Bool
    private let original: String
    private let stateIndex: String.Index

    init?(_ line: String) {
        let task = line.drop(while: { $0 == " " || $0 == "\t" })
        guard task.hasPrefix("- [ ] ") || task.hasPrefix("- [x] ") || task.hasPrefix("- [X] ") else { return nil }
        original = line
        indentation = String(line[..<task.startIndex])
        stateIndex = task.index(task.startIndex, offsetBy: 3)
        isChecked = line[stateIndex] != " "
        text = String(task.dropFirst(6))
    }

    var indentationColumns: Int {
        indentation.prefix(24).reduce(0) { min(24, $0 + ($1 == "\t" ? 4 : 1)) }
    }

    func settingChecked(_ checked: Bool) -> String {
        guard checked != isChecked else { return original }
        var result = original
        // Change only the matched checkbox state; preserve indentation and task text verbatim.
        result.replaceSubrange(stateIndex...stateIndex, with: checked ? "x" : " ")
        return result
    }
}

struct Note: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title = ""
    var body = ""
    var tags: [String] = []
    var folder = ""
    var status = "active"
    var pinned = false
    var created = Date().timeIntervalSince1970 * 1000
    var updated = Date().timeIntervalSince1970 * 1000
    var sample = false
    var displayTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L("ملاحظة بلا عنوان") : title }
    var date: Date { Date(timeIntervalSince1970: updated / 1000) }
    var words: Int { body.split(whereSeparator: \.isWhitespace).count }
}
struct NoteFolder: Codable, Identifiable, Hashable { var id = UUID().uuidString; var name: String }
struct Notebook: Codable {
    var version = 1
    var folders: [NoteFolder] = []
    var notes: [Note] = []
    func validated() throws -> Notebook {
        guard version == 1, notes.count <= 10_000, folders.count <= 500,
              Set(folders.map(\.id)).count == folders.count,
              Set(notes.map(\.id)).count == notes.count else { throw WaraqaError.invalidBackup }
        let ids = Set(folders.map(\.id))
        guard folders.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.name.count <= 80 }),
              notes.allSatisfy({ $0.title.count <= 300 && $0.body.count <= 200_000 && $0.tags.count <= 20 && $0.tags.allSatisfy { $0.count <= 40 } && ["active","archive","trash"].contains($0.status) && ($0.folder.isEmpty || ids.contains($0.folder)) && $0.created.isFinite && $0.updated.isFinite }) else { throw WaraqaError.invalidBackup }
        return self
    }
    func filtered(view: String, query: String) -> [Note] {
        let q = Self.normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return notes.filter { n in
            let status = view == "trash" ? "trash" : view == "archive" ? "archive" : "active"
            guard n.status == status, view != "pinned" || n.pinned else { return false }
            if view.hasPrefix("folder:"), n.folder != String(view.dropFirst(7)) { return false }
            if view.hasPrefix("tag:"), !n.tags.contains(String(view.dropFirst(4))) { return false }
            return q.isEmpty || Self.normalized(([n.title,n.body] + n.tags).joined(separator: " ")).contains(q)
        }.sorted { $0.pinned != $1.pinned ? $0.pinned : $0.updated > $1.updated }
    }
    static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive,.caseInsensitive], locale: Locale(identifier:"ar"))
            .replacingOccurrences(of:"[أإآ]",with:"ا",options:.regularExpression)
            .replacingOccurrences(of:"ى",with:"ي")
    }
    func merging(_ incoming: Notebook) throws -> Notebook {
        let incoming = try incoming.validated()
        var result = self, map: [String:String] = [:]
        for f in incoming.folders {
            if let existing = result.folders.first(where: { $0.name == f.name }) { map[f.id] = existing.id }
            else { let folder = NoteFolder(name:f.name); result.folders.append(folder); map[f.id] = folder.id }
        }
        for var n in incoming.notes { n.id = UUID().uuidString; n.folder = map[n.folder] ?? ""; n.sample = false; result.notes.append(n) }
        return try result.validated()
    }
    static var welcome: Notebook {
        let f = NoteFolder(name:L("شخصي")), w = NoteFolder(name:L("العمل")), i = NoteFolder(name:L("أفكار وإلهام"))
        return Notebook(folders:[f,w,i],notes:[
            Note(title:L("مساحة لأفكارك الكبيرة"),body:L("أهلًا بك في ورقة 🌿\n\nبعض الأفكار تحتاج فقط إلى مساحة هادئة. هنا، اكتب ما يدور في بالك، ورتّب يومك، واحتفظ بما يستحق أن تتذكّره.\n\n## ابدأ بفكرة واحدة\nلا تحتاج إلى نظام معقّد أو صفحة مثالية. اضغط زر الإضافة واكتب أول سطر. الباقي يأتي مع الكتابة.\n\n## مساحة بسيطة، وملكك أنت\n- حفظ تلقائي على جهازك.\n- لا حسابات ولا إعلانات ولا تتبّع.\n- تصدير واستيراد عبر الملفات.\n\n> اكتب لتفسح مكانًا في ذهنك، لا لتملأ صفحة.\n\nهذه ملاحظة تجريبية. يمكنك إزالتها من الإعدادات."),tags:[L("البداية")],folder:f.id,pinned:true,sample:true),
            Note(title:L("أشياء صغيرة تصنع يومًا جميلًا"),body:L("قائمة تجريبية لأيام أخف.\n\n- [x] قهوة الصباح بعيدًا عن الهاتف\n- [ ] المشي لمدة عشرين دقيقة\n- [ ] قراءة عشر صفحات\n- [ ] الاتصال بصديق قديم\n\nلا بأس أن تنجز شيئًا واحدًا فقط اليوم."),tags:[L("يوميات")],folder:f.id,sample:true),
            Note(title:L("فكرة تستحق أن تكبر"),body:L("ماذا لو خصّصت كل أسبوع ساعة لفكرة واحدة؟\n\n## الفكرة\nمساحة صغيرة نجتمع فيها لنتبادل الكتب والأفكار.\n\n## أول خطوة\nأختار كتابًا وأدعو صديقين، ونبدأ."),tags:[L("إلهام")],folder:i.id,sample:true),
            Note(title:L("خطة الأسبوع"),body:L("## التركيز هذا الأسبوع\nإنهاء العمل الأهم قبل البدء بالجديد.\n\n- [ ] مراجعة الأولويات\n- [ ] تخصيص وقت للعمل العميق\n- [ ] ترك مساحة للراحة\n\nالوضوح يأتي من البدء."),tags:[L("تخطيط")],folder:w.id,sample:true)
        ])
    }
}
enum WaraqaError: LocalizedError {
    case invalidBackup, unsupportedEncryption, wrongPassword, tooLarge, storageLimit, noPrevious, noNote, spaceLocked, unlockCancelled
    var errorDescription: String? {
        switch self {
        case .invalidBackup: L("النسخة الاحتياطية غير سليمة أو غير مدعومة.")
        case .unsupportedEncryption: L("إعدادات التشفير غير مدعومة.")
        case .wrongPassword: L("كلمة المرور غير صحيحة أو البيانات تالفة.")
        case .tooLarge: L("الحد الأقصى لملف الاستيراد ٢٤ ميغابايت، وللملاحظة ٢٠٠ ألف حرف.")
        case .storageLimit: L("تجاوزت البيانات حد التخزين المدعوم في هذا الإصدار. صدّر نسخة من عملك قبل إغلاق التطبيق.")
        case .noPrevious: L("لا توجد نسخة محلية سابقة للاستعادة.")
        case .noNote: L("هذه الملاحظة غير موجودة.")
        case .spaceLocked: L("افتح المساحة أولًا.")
        case .unlockCancelled: L("أُلغي الفتح عند قفل التطبيق. حاول مجددًا.")
        }
    }
}


enum AppLanguage {
    static var isArabic: Bool {
        let selected = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        if selected != "system" { return selected == "ar" }
        return Locale.preferredLanguages.first?.hasPrefix("ar") == true
    }
    static var locale: Locale { Locale(identifier: isArabic ? "ar" : "en") }
    static let english: [String: String] = [
        "أفكارك، لك وحدك": "Your thoughts, yours alone",
        "مساحة مجانية ومفتوحة المصدر، محفوظة على جهازك.": "Free, open source, and saved on your device.",
        "تصدير نسخة مشفرة": "Export encrypted backup",
        "تصدير نسخة احتياطية": "Export backup",
        "استيراد ملاحظات": "Import notes",
        "نسخة من أفكارك": "Back up your thoughts",
        "حذف التطبيق يزيل ملاحظاته المحلية. احتفظ بنسخ خارج التطبيق. ": "Deleting the app removes its local notes. Keep backups outside the app. ",
        "النسخة الكاملة مشفرة بكلمة مرور المساحة.": "The full backup uses your space password.",
        "النسخة الحالية قابلة للقراءة؛ احفظها في مكان موثوق.": "This backup is readable. Save it somewhere you trust.",
        "القفل المشفر مفعّل": "Encryption is on",
        "قفل المساحة الآن": "Lock space now",
        "تفعيل القفل المشفر": "Enable password encryption",
        "الخصوصية والقفل": "Privacy and lock",
        "تُقفل المساحة عند انتقال التطبيق للخلفية أو مرور خمس دقائق دون تفاعل. كلمة المرور لا تُحفظ ولا يمكن استعادتها.": "After saving, your space locks in the background or after five minutes without activity. Your password is not stored and cannot be recovered.",
        "يحمي iOS ملفات التطبيق بقفل الجهاز. يمكنك إضافة كلمة مرور لتشفير الملاحظات نفسها، بما فيها العناوين والوسوم.": "iOS protects app files when the device is locked. Add a password to encrypt your notes, including titles and tags.",
        "مجلداتي": "Folders",
        "إزالة مجلد ": "Remove folder ",
        "مجلد جديد": "New folder",
        "عن ورقة والخصوصية": "About Thought Meadow & privacy",
        "المساعدة والملاحظات": "Help & feedback",
        "الإصدار": "Version",
        "المزامنة والقوائم المشتركة مخططة لخدمة اختيارية لاحقًا. لا توجد مدفوعات أو اشتراكات في هذا الإصدار.": "Sync and shared lists are planned as an optional service. This version has no payments or subscriptions.",
        "إزالة الملاحظات التجريبية": "Remove sample notes",
        "تُنقل الأمثلة، بما فيها الأمثلة المعدّلة، إلى المحذوفات. ملاحظاتك الجديدة تبقى كما هي.": "Samples, including edited samples, move to Trash. Your own new notes stay where they are.",
        "إعدادات مساحتك": "Your space",
        "تم": "Done",
        "اسم المجلد": "Folder name",
        "إضافة": "Add",
        "اختر اسمًا جديدًا وغير فارغ، بحد أقصى ٨٠ حرفًا.": "Choose a unique, nonempty name of up to 80 characters.",
        "إلغاء": "Cancel",
        "نقل جميع الأمثلة إلى المحذوفات؟": "Move all samples to Trash?",
        "نقل الأمثلة": "Move samples",
        "إزالة المجلد؟ ستبقى ملاحظاته محفوظة دون مجلد.": "Remove this folder? Its notes will be kept without a folder.",
        "إزالة المجلد": "Remove folder",
        "كلمة مرور جديدة": "New password",
        "تأكيد كلمة المرور": "Confirm password",
        "اختر ١٢ حرفًا على الأقل. احتفظ بكلمة المرور؛ لا توجد طريقة لاستعادتها. تُشفّر الملاحظات والعناوين والمجلدات والوسوم كلها.": "Choose at least 12 characters. Keep your password safe: it cannot be recovered. Notes, titles, folders and tags will all be encrypted.",
        "كلمتا المرور غير متطابقتين.": "The passwords do not match.",
        "تشفير المساحة": "Encrypt space",
        "احمِ مساحة أفكارك": "Protect your space",
        "لن تُستبدل ملاحظاتك. إعادة استيراد النسخة نفسها تنشئ نسخًا إضافية.": "Your notes will be kept. Importing the same backup again creates additional copies.",
        "إضافة الملاحظات": "Add notes",
        "كلمة مرور النسخة الاحتياطية": "Backup password",
        "فتح النسخة المشفرة": "Unlock backup",
        "مراجعة الاستيراد": "Review import",
        "مساحة لأفكارك": "Room for your thoughts",
        "ورقة تطبيق ملاحظات عربي أصلي لـ iPhone، مجاني ومفتوح المصدر برخصة MIT. لا يحتاج إلى حساب أو اتصال بالإنترنت.": "Thought Meadow is a native iPhone notes app, free and open source under the MIT license. No account or internet connection is needed.",
        "البيانات": "Data",
        "لا يرسل التطبيق الملاحظات أو كلمات المرور إلى خادم، ولا يحتوي على أدوات تتبّع أو إعلانات أو مكتبات خارجية. عند التصدير تختار أنت أين يُحفظ الملف، وقد تختار خدمة سحابية من تطبيق الملفات.": "The app does not send notes or passwords to a server. There are no trackers, ads or third-party libraries. You choose where exports are saved, including any cloud provider you select in Files.",
        "القفل والتخزين": "Lock & storage",
        "قبل تفعيل القفل، ملفات البيانات قابلة للقراءة داخل مساحة التطبيق وتخضع لحماية iOS. القفل الاختياري يستخدم AES-256-GCM واشتقاق مفتاح PBKDF2-SHA-256 مع ٦٠٠ ألف دورة. المفتاح يبقى في الذاكرة أثناء الفتح. لا يحمي القفل جهازًا مخترقًا.": "Before password encryption is enabled, readable app data is protected by iOS. The optional lock uses AES-256-GCM with PBKDF2-SHA-256 and 600,000 iterations. The key stays in memory while unlocked. This cannot protect a compromised device.",
        "نسخ احتياطية": "Backups",
        "استبعدنا مجلد البيانات من النسخ السحابي التلقائي. حذف التطبيق قد يحذف ملاحظاتك. صدّر نسخة دورية خارج التطبيق؛ احتفظ بكلمة مرور النسخة المشفرة. النسخة المحلية السابقة ليست بديلًا عن نسخة خارج الجهاز.": "App data is excluded from automatic cloud backup. Deleting the app may delete your notes. Export backups regularly and keep encrypted-backup passwords safe. The previous local save is not a substitute for a backup outside your device.",
        "إصدار أول": "First release",
        "لم يخضع التطبيق لتدقيق أمني مستقل بعد. المزامنة والقوائم المشتركة والاشتراك ليست متاحة حاليًا.": "The app has not yet had an independent security audit. Sync, shared lists and subscriptions are not available in this release.",
        "مجلد": "Folder",
        "كل الملاحظات": "All notes",
        "المثبّتة": "Pinned",
        "الأرشيف": "Archive",
        "المحذوفات": "Trash",
        "ملاحظاتي": "My notes",
        "ورقة": "Thought Meadow",
        "تنبيه": "Notice",
        "حسنًا": "OK",
        "مساحة لأفكارك.": "Room for your thoughts.",
        "كل فكرة تستحق مكانًا.": "Every idea deserves a place.",
        "مساحة لفكرتك القادمة": "Room for your next idea",
        "لم نجد هذه الفكرة بعد": "No notes found",
        "الملاحظات المحذوفة تظهر هنا، ويمكنك استعادتها.": "Deleted notes appear here. You can restore them.",
        "ابدأ ملاحظة جديدة من زر الإضافة.": "Tap New note to start writing.",
        "جرّب كلمة أخرى أو ابحث في كل الملاحظات.": "Try another word or search All notes.",
        "حذف": "Delete",
        "استعادة": "Restore",
        "إلغاء التثبيت": "Unpin",
        "تثبيت": "Pin",
        "ابحث في ملاحظاتك…": "Search your notes…",
        "الإعدادات": "Settings",
        "لم يكتمل": "Could not save",
        "ملاحظة جديدة": "New note",
        "الوسوم": "Tags",
        "تصفية الملاحظات": "Filter notes",
        "أفكارك في مساحة مقفلة.": "Your thoughts are in a locked space.",
        "كلمة مرور المساحة": "Space password",
        "فتح مساحتي": "Unlock my space",
        "كلمة المرور تبقى على جهازك. لا يمكن استعادتها.": "Your password stays on your device. It cannot be recovered.",
        "تعذّر فتح المساحة": "Could not open your space",
        "جارٍ التحميل…": "Loading…",
        "تصدير البيانات المحفوظة للفحص": "Export saved data for recovery",
        "استعادة النسخة المحلية السابقة": "Restore previous local save",
        "استعادة آخر حفظ سابق؟ صدّر بيانات الفحص أولًا. قد تفقد آخر تعديل.": "Restore the previous save? Export recovery data first. Your latest changes may be lost.",
        "استعادة النسخة السابقة": "Restore previous save",
        "صفحة جديدة، وإمكانات كثيرة…": "A fresh page, full of possibility…",
        "نجهّز مساحة لأفكارك…": "Preparing your space…",
        "المساحة مقفلة": "Space locked",
        "محفوظ على جهازك": "Saved on your device",
        "تعذّر فتح المساحة. لم نستبدل بياناتك. ": "Could not open your space. Your data was not replaced. ",
        "جارٍ الحفظ…": "Saving…",
        "لم يكتمل الحفظ — صدّر نسخة الآن": "Could not save — export a backup now",
        "وصلت للحد الأقصى للملاحظات.": "You have reached the note limit.",
        "ملاحظة بلا عنوان": "Untitled note",
        "شخصي": "Personal",
        "العمل": "Work",
        "أفكار وإلهام": "Ideas",
        "مساحة لأفكارك الكبيرة": "Room for your big ideas",
        "البداية": "getting-started",
        "أشياء صغيرة تصنع يومًا جميلًا": "Little things, a brighter day",
        "يوميات": "everyday",
        "فكرة تستحق أن تكبر": "An idea worth growing",
        "إلهام": "inspiration",
        "خطة الأسبوع": "This week's plan",
        "تخطيط": "planning",
        "النسخة الاحتياطية غير سليمة أو غير مدعومة.": "This backup is invalid or unsupported.",
        "إعدادات التشفير غير مدعومة.": "These encryption settings are unsupported.",
        "كلمة المرور غير صحيحة أو البيانات تالفة.": "Incorrect password or damaged data.",
        "الحد الأقصى لملف الاستيراد ٢٤ ميغابايت، وللملاحظة ٢٠٠ ألف حرف.": "Import files can be up to 24 MB. Each note can contain up to 200,000 characters.",
        "تجاوزت البيانات حد التخزين المدعوم في هذا الإصدار. صدّر نسخة من عملك قبل إغلاق التطبيق.": "This version's storage limit has been reached. Export your work before closing the app.",
        "لا توجد نسخة محلية سابقة للاستعادة.": "There is no previous local save to restore.",
        "هذه الملاحظة غير موجودة.": "This note could not be found.",
        "افتح المساحة أولًا.": "Unlock your space first.",
        "أُلغي الفتح عند قفل التطبيق. حاول مجددًا.": "Unlocking was cancelled when the app locked. Try again.",
        "وضع المحرر": "Editor mode",
        "كتابة": "Write",
        "معاينة": "Preview",
        "هذه الملاحظة في المحذوفات.": "This note is in Trash.",
        "مساحة للتجربة": "A sample to explore",
        "عنوان الملاحظة": "Note title",
        "وسم": "Tag",
        "محتوى الملاحظة": "Note content",
        "قفل الآن": "Lock now",
        "ملاحظة": "Note",
        "نقل إلى مجلد": "Move to folder",
        "دون مجلد": "No folder",
        "إلغاء الأرشفة": "Unarchive",
        "أرشفة": "Archive",
        "تصدير Markdown": "Export Markdown",
        "الخروج من التركيز": "Leave focus mode",
        "وضع التركيز": "Focus mode",
        "حذف نهائي": "Delete permanently",
        "نقل إلى المحذوفات": "Move to Trash",
        "خيارات الملاحظة": "Note options",
        "اختر ملاحظة": "Choose a note",
        "افصل الوسوم بفاصلة": "Separate tags with commas",
        "اترك الحقل فارغًا لإزالة الوسوم.": "Leave empty to remove tags.",
        "وسوم الملاحظة": "Note tags",
        "حفظ": "Save",
        "سيكون ملف Markdown قابلًا للقراءة خارج حماية كلمة المرور.": "The Markdown file will be readable outside password protection.",
        "تصدير دون تشفير": "Export unencrypted",
        "حذف الملاحظة نهائيًا؟ لا يمكن استعادتها من المحذوفات.": "Permanently delete this note? It cannot be restored from Trash.",
        "مكتملة": "Completed",
        "غير مكتملة": "Not completed",
        "أهلًا بك في ورقة 🌿\n\nبعض الأفكار تحتاج فقط إلى مساحة هادئة. هنا، اكتب ما يدور في بالك، ورتّب يومك، واحتفظ بما يستحق أن تتذكّره.\n\n## ابدأ بفكرة واحدة\nلا تحتاج إلى نظام معقّد أو صفحة مثالية. اضغط زر الإضافة واكتب أول سطر. الباقي يأتي مع الكتابة.\n\n## مساحة بسيطة، وملكك أنت\n- حفظ تلقائي على جهازك.\n- لا حسابات ولا إعلانات ولا تتبّع.\n- تصدير واستيراد عبر الملفات.\n\n> اكتب لتفسح مكانًا في ذهنك، لا لتملأ صفحة.\n\nهذه ملاحظة تجريبية. يمكنك إزالتها من الإعدادات.": "Welcome to Thought Meadow 🌿\n\nSome ideas just need a quiet place. Capture a thought, plan your day, and keep what matters.\n\n## Start with one idea\nYou don't need a perfect system. Tap New note and write your first line.\n\n## Simple, and yours\n- Automatic saving on your device.\n- No account, ads or tracking.\n- Import and export through Files.\n\n> Write to make room in your mind.\n\nThis is a sample note. Move samples to Trash from Settings whenever you like.",
        "قائمة تجريبية لأيام أخف.\n\n- [x] قهوة الصباح بعيدًا عن الهاتف\n- [ ] المشي لمدة عشرين دقيقة\n- [ ] قراءة عشر صفحات\n- [ ] الاتصال بصديق قديم\n\nلا بأس أن تنجز شيئًا واحدًا فقط اليوم.": "A small list for a lighter day.\n\n- [x] Morning coffee without my phone\n- [ ] Take a twenty-minute walk\n- [ ] Read ten pages\n- [ ] Call an old friend\n\nOne small thing is enough to start.",
        "ماذا لو خصّصت كل أسبوع ساعة لفكرة واحدة؟\n\n## الفكرة\nمساحة صغيرة نجتمع فيها لنتبادل الكتب والأفكار.\n\n## أول خطوة\nأختار كتابًا وأدعو صديقين، ونبدأ.": "What if one hour each week was for a single idea?\n\n## The idea\nA small gathering to share books and thoughts.\n\n## First step\nChoose a book, invite two friends, and begin.",
        "## التركيز هذا الأسبوع\nإنهاء العمل الأهم قبل البدء بالجديد.\n\n- [ ] مراجعة الأولويات\n- [ ] تخصيص وقت للعمل العميق\n- [ ] ترك مساحة للراحة\n\nالوضوح يأتي من البدء.": "## This week's focus\nFinish the important work before starting something new.\n\n- [ ] Review priorities\n- [ ] Make time for deep work\n- [ ] Leave room for rest\n\nClarity comes from beginning."
    ]
}

func L(_ arabic: String) -> String {
    if AppLanguage.isArabic {
        return arabic.replacingOccurrences(of: "ورقة", with: "مرج الأفكار")
    }
    return AppLanguage.english[arabic] ?? arabic
}
