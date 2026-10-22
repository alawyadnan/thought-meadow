import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: NotebookStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var language = "system"
    @ViewState private var encryptionSheet = false
    @ViewState private var password = ""
    @ViewState private var confirmation = ""
    @ViewState private var busy = false
    @ViewState private var localError = ""
    @ViewState private var exporter = false
    @ViewState private var document: ExportDocument?
    @ViewState private var importer = false
    @ViewState private var importSheet = false
    @ViewState private var incomingEnvelope: VaultEnvelope?
    @ViewState private var incoming: Notebook?
    @ViewState private var importPassword = ""
    @ViewState private var newFolder = ""
    @ViewState private var folderPrompt = false
    @ViewState private var removeSamples = false
    @ViewState private var folderToRemove: NoteFolder?
    @ViewState private var showFolderRemoval = false
    @ViewState private var information = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label { VStack(alignment:.leading,spacing:5) { Text(L("أفكارك، لك وحدك")).font(.headline); Text(L("مساحة مجانية ومفتوحة المصدر، محفوظة على جهازك.")).font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName:"leaf.fill").foregroundStyle(Color.waraqaGreen) }
                }
                Section {
                    Picker(AppLanguage.isArabic ? "لغة التطبيق" : "App language", selection: $language) {
                        Text(AppLanguage.isArabic ? "لغة الجهاز" : "Device language").tag("system")
                        Text("English").tag("en")
                        Text("العربية").tag("ar")
                    }
                }
                Section {
                    Button { exportBackup() } label: { Label(store.isEncrypted ? L("تصدير نسخة مشفرة") : L("تصدير نسخة احتياطية"),systemImage:"square.and.arrow.up") }
                    Button { importer = true } label: { Label(L("استيراد ملاحظات"),systemImage:"square.and.arrow.down") }
                } header: { Text(L("نسخة من أفكارك")) } footer: { Text(L("حذف التطبيق يزيل ملاحظاته المحلية. احتفظ بنسخ خارج التطبيق. ") + (store.isEncrypted ? L("النسخة الكاملة مشفرة بكلمة مرور المساحة.") : L("النسخة الحالية قابلة للقراءة؛ احفظها في مكان موثوق."))) }
                Section {
                    if store.isEncrypted { Label(L("القفل المشفر مفعّل"),systemImage:"lock.shield"); Button(L("قفل المساحة الآن")) { dismiss(); store.lock() } }
                    else { Button { localError = ""; encryptionSheet = true } label: { Label(L("تفعيل القفل المشفر"),systemImage:"lock") } }
                } header: { Text(L("الخصوصية والقفل")) } footer: { Text(store.isEncrypted ? L("تُقفل المساحة عند انتقال التطبيق للخلفية أو مرور خمس دقائق دون تفاعل. كلمة المرور لا تُحفظ ولا يمكن استعادتها.") : L("يحمي iOS ملفات التطبيق بقفل الجهاز. يمكنك إضافة كلمة مرور لتشفير الملاحظات نفسها، بما فيها العناوين والوسوم.")) }
                Section(L("مجلداتي")) {
                    ForEach(store.notebook.folders) { f in HStack { Label(f.name,systemImage:"folder"); Spacer(); Button { folderToRemove = f; showFolderRemoval = true } label: { Image(systemName:"minus.circle").foregroundStyle(.secondary) }.buttonStyle(.borderless).accessibilityLabel(L("إزالة مجلد ") + f.name) } }
                    Button { newFolder = ""; folderPrompt = true } label: { Label(L("مجلد جديد"),systemImage:"folder.badge.plus") }
                }
                Section {
                    Button { information = true } label: { Label(L("عن ورقة والخصوصية"),systemImage:"info.circle") }
                    Link(destination:URL(string:"mailto:allaw.68@gmail.com?subject=Thought Meadow%20Support")!) { Label(L("المساعدة والملاحظات"),systemImage:"envelope") }
                    HStack { Text(L("الإصدار")); Spacer(); Text("1.0.0 (3)").foregroundStyle(.secondary).monospacedDigit() }
                    Text(L("المزامنة والقوائم المشتركة مخططة لخدمة اختيارية لاحقًا. لا توجد مدفوعات أو اشتراكات في هذا الإصدار.")).font(.caption).foregroundStyle(.secondary)
                }
                if store.notebook.notes.contains(where:\.sample) { Section { Button(L("إزالة الملاحظات التجريبية"),role:.destructive) { removeSamples = true } } footer: { Text(L("تُنقل الأمثلة، بما فيها الأمثلة المعدّلة، إلى المحذوفات. ملاحظاتك الجديدة تبقى كما هي.")) } }
            }
            .navigationTitle(L("إعدادات مساحتك")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button(L("تم")) { dismiss() } } }
            .fileExporter(isPresented:$exporter,document:document,contentType:.json,defaultFilename:"alawynote-backup.json") { result in if case .failure(let error) = result { store.error = error.localizedDescription }; document = nil }
            .fileImporter(isPresented:$importer,allowedContentTypes:[.json,.plainText,.data]) { result in
                do { let url = try result.get(), access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; incomingEnvelope = try store.readImport(url); incoming = incomingEnvelope?.data; importPassword = ""; localError = ""; importSheet = true }
                catch { store.error = error.localizedDescription }
            }
            .sheet(isPresented:$encryptionSheet,onDismiss:{ password = ""; confirmation = "" }) { encryptionForm }
            .sheet(isPresented:$importSheet,onDismiss:{ incoming = nil; incomingEnvelope = nil; importPassword = "" }) { importForm }
            .sheet(isPresented:$information) { informationView }
            .alert(L("مجلد جديد"),isPresented:$folderPrompt) { TextField(L("اسم المجلد"),text:$newFolder); Button(L("إضافة")) { do { try store.addFolder(newFolder) } catch { store.error = L("اختر اسمًا جديدًا وغير فارغ، بحد أقصى ٨٠ حرفًا.") } }; Button(L("إلغاء"),role:.cancel) {} }
            .confirmationDialog(L("نقل جميع الأمثلة إلى المحذوفات؟"),isPresented:$removeSamples,titleVisibility:.visible) { Button(L("نقل الأمثلة"),role:.destructive) { store.removeSamples() } }
            .confirmationDialog(L("إزالة المجلد؟ ستبقى ملاحظاته محفوظة دون مجلد."),isPresented:$showFolderRemoval,titleVisibility:.visible) { Button(L("إزالة المجلد"),role:.destructive) { if let f = folderToRemove { store.removeFolder(f.id) } } }
        }
    }
    private func exportBackup() { do { document = ExportDocument(bytes:try store.backup()); exporter = true } catch { store.error = error.localizedDescription } }
    private var encryptionForm: some View {
        NavigationStack {
            Form {
                Section { SecureField(L("كلمة مرور جديدة"),text:$password).textContentType(.newPassword); SecureField(L("تأكيد كلمة المرور"),text:$confirmation).textContentType(.newPassword) } footer: { Text(L("اختر ١٢ حرفًا على الأقل. احتفظ بكلمة المرور؛ لا توجد طريقة لاستعادتها. تُشفّر الملاحظات والعناوين والمجلدات والوسوم كلها.")) }
                if !localError.isEmpty { Text(localError).foregroundStyle(.red).font(.caption) }
                Button { busy = true; localError = ""; Task { do { guard password == confirmation else { localError = L("كلمتا المرور غير متطابقتين."); busy = false; return }; try await store.enableEncryption(password:password); password = ""; confirmation = ""; encryptionSheet = false } catch { localError = error.localizedDescription }; busy = false } } label: { HStack { Text(L("تشفير المساحة")); Spacer(); if busy { ProgressView() } } }.disabled(busy || password.count < 12 || confirmation.isEmpty)
            }.navigationTitle(L("احمِ مساحة أفكارك")).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement:.cancellationAction) { Button(L("إلغاء")) { encryptionSheet = false }.disabled(busy) } }.interactiveDismissDisabled(busy)
        }
    }
    private var importForm: some View {
        NavigationStack {
            Form {
                if let incoming {
                    Section { Text(AppLanguage.isArabic ? "سيُضاف \(incoming.notes.count) من الملاحظات و\(incoming.folders.count) من المجلدات." : "Add \(incoming.notes.count) notes and \(incoming.folders.count) folders."); Text(L("لن تُستبدل ملاحظاتك. إعادة استيراد النسخة نفسها تنشئ نسخًا إضافية.")).font(.caption).foregroundStyle(.secondary) }
                    Button(L("إضافة الملاحظات")) { do { try store.merge(incoming); importSheet = false } catch { localError = error.localizedDescription } }
                } else {
                    SecureField(L("كلمة مرور النسخة الاحتياطية"),text:$importPassword).textContentType(.password)
                    Button { busy = true; localError = ""; Task { do { guard let envelope = incomingEnvelope else { throw WaraqaError.invalidBackup }; incoming = try await store.decodeImport(envelope,password:importPassword); importPassword = "" } catch { localError = error.localizedDescription }; busy = false } } label: { HStack { Text(L("فتح النسخة المشفرة")); Spacer(); if busy { ProgressView() } } }.disabled(busy || importPassword.isEmpty)
                }
                if !localError.isEmpty { Text(localError).font(.caption).foregroundStyle(.red) }
            }.navigationTitle(L("مراجعة الاستيراد")).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement:.cancellationAction) { Button(L("إلغاء")) { importSheet = false }.disabled(busy) } }.interactiveDismissDisabled(busy)
        }
    }
    private var informationView: some View {
        NavigationStack {
            List {
                Section(L("مساحة لأفكارك")) { Text(L("ورقة تطبيق ملاحظات عربي أصلي لـ iPhone، مجاني ومفتوح المصدر برخصة MIT. لا يحتاج إلى حساب أو اتصال بالإنترنت.")) }
                Section(L("البيانات")) { Text(L("لا يرسل التطبيق الملاحظات أو كلمات المرور إلى خادم، ولا يحتوي على أدوات تتبّع أو إعلانات أو مكتبات خارجية. عند التصدير تختار أنت أين يُحفظ الملف، وقد تختار خدمة سحابية من تطبيق الملفات.")) }
                Section(L("القفل والتخزين")) { Text(L("قبل تفعيل القفل، ملفات البيانات قابلة للقراءة داخل مساحة التطبيق وتخضع لحماية iOS. القفل الاختياري يستخدم AES-256-GCM واشتقاق مفتاح PBKDF2-SHA-256 مع ٦٠٠ ألف دورة. المفتاح يبقى في الذاكرة أثناء الفتح. لا يحمي القفل جهازًا مخترقًا.")) }
                Section(L("نسخ احتياطية")) { Text(L("استبعدنا مجلد البيانات من النسخ السحابي التلقائي. حذف التطبيق قد يحذف ملاحظاتك. صدّر نسخة دورية خارج التطبيق؛ احتفظ بكلمة مرور النسخة المشفرة. النسخة المحلية السابقة ليست بديلًا عن نسخة خارج الجهاز.")) }
                Section(L("إصدار أول")) { Text(L("لم يخضع التطبيق لتدقيق أمني مستقل بعد. المزامنة والقوائم المشتركة والاشتراك ليست متاحة حاليًا.")) }
                Section("MIT License") { Text("Copyright © 2026 Waraqa contributors\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files, to deal in the Software without restriction, including the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies, subject to retaining this notice and the MIT license.\n\nTHE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND. See the full LICENSE in the source distribution.").font(.caption).environment(\.layoutDirection,.leftToRight) }
            }.navigationTitle(L("عن ورقة والخصوصية")).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement:.confirmationAction) { Button(L("تم")) { information = false } } }
        }
    }
}
