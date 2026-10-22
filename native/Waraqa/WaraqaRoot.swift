import SwiftUI
import Combine
import UniformTypeIdentifiers

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json,.plainText,.data] }
    var bytes: Data
    init(bytes: Data) { self.bytes = bytes }
    init(configuration: ReadConfiguration) throws { bytes = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents:bytes) }
}
struct WaraqaRoot: View {
    @EnvironmentObject private var store: NotebookStore
    @Environment(\.scenePhase) private var phase
    @ViewState private var path: [String] = []
    @ViewState private var view = "all"
    @ViewState private var query = ""
    @ViewState private var settings = false
    @ViewState private var password = ""
    @ViewState private var unlockError = ""
    @ViewState private var recoveryExport: ExportDocument?
    @ViewState private var exportingRecovery = false
    @ViewState private var restoreConfirm = false
    private let timer = Timer.publish(every:15,on:.main,in:.common).autoconnect()
    private var notes: [Note] { store.notebook.filtered(view:view,query:query) }
    private var viewTitle: String {
        if view.hasPrefix("folder:") { return store.notebook.folders.first { $0.id == String(view.dropFirst(7)) }?.name ?? L("مجلد") }
        if view.hasPrefix("tag:") { return "# " + view.dropFirst(4) }
        return ["all":L("كل الملاحظات"),"pinned":L("المثبّتة"),"archive":L("الأرشيف"),"trash":L("المحذوفات")][view] ?? L("ملاحظاتي")
    }
    var body: some View {
        ZStack {
            if store.locked { lockedView }
            else if !store.loaded { recoveryView }
            else { notebookView }
            if phase != .active {
                Color(uiColor:.systemBackground).ignoresSafeArea()
                VStack(spacing:16) { Image(systemName:"leaf.fill").font(.system(size:50)).foregroundStyle(Color.waraqaGreen); Text(L("ورقة")).font(.largeTitle.bold()) }.accessibilityHidden(true)
            }
        }
        .onChange(of:phase) { _, next in
            if next == .background { store.flush(); store.lock() }
            if next == .active { store.activity() }
        }
        .onChange(of:store.locked) { _, locked in if locked { path = []; settings = false; query = ""; password = ""; recoveryExport = nil } }
        .onChange(of:store.isEncrypted) { _, encrypted in if encrypted && phase != .active { store.lock() } }
        .onReceive(timer) { _ in if Date().timeIntervalSince(store.lastActivity) >= 300 { store.lock() } }
        .alert(L("تنبيه"),isPresented:Binding(get:{ store.error != nil && store.loaded },set:{ if !$0 { store.error = nil } })) { Button(L("حسنًا"),role:.cancel) {} } message: { Text(store.error ?? "") }
    }
    private var notebookView: some View {
        NavigationStack(path:$path) {
            List {
                Section {
                    VStack(alignment:.leading,spacing:12) {
                        HStack(spacing:12) {
                            Image(systemName:"leaf.fill").font(.title).foregroundStyle(Color.waraqaGreen).padding(12).background(Color.waraqaGreen.opacity(0.1),in:RoundedRectangle(cornerRadius:16))
                            VStack(alignment:.leading,spacing:4) { Text(L("ورقة")).font(.system(size:34,weight:.bold,design:.serif)).lineLimit(1).minimumScaleFactor(0.65); Text(L("مساحة لأفكارك.")).font(.subheadline).foregroundStyle(.secondary) }
                            Spacer()
                        }
                        Text(L("كل فكرة تستحق مكانًا.")).font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical,12)
                }.listRowBackground(Color.clear).listRowSeparator(.hidden)
                Section {
                    if notes.isEmpty {
                        ContentUnavailableView(query.isEmpty ? L("مساحة لفكرتك القادمة") : L("لم نجد هذه الفكرة بعد"),systemImage:query.isEmpty ? "note.text" : "magnifyingglass",description:Text(query.isEmpty ? (view == "trash" ? L("الملاحظات المحذوفة تظهر هنا، ويمكنك استعادتها.") : L("ابدأ ملاحظة جديدة من زر الإضافة.")) : L("جرّب كلمة أخرى أو ابحث في كل الملاحظات.")))
                            .listRowBackground(Color.clear)
                    }
                    ForEach(notes) { note in
                        NavigationLink(value:note.id) { NoteRow(note:note) }
                            .swipeActions(edge:.trailing,allowsFullSwipe:false) {
                                if view != "trash" { Button(role:.destructive) { store.setStatus(note.id,"trash") } label: { Label(L("حذف"),systemImage:"trash") } }
                                else { Button { store.setStatus(note.id,"active") } label: { Label(L("استعادة"),systemImage:"arrow.uturn.backward") }.tint(.waraqaGreen) }
                            }
                            .swipeActions(edge:.leading,allowsFullSwipe:false) {
                                if view != "trash" { Button { store.update(note.id) { $0.pinned.toggle() } } label: { Label(note.pinned ? L("إلغاء التثبيت") : L("تثبيت"),systemImage:"pin") }.tint(.waraqaGreen) }
                            }
                    }
                } header: { HStack { Text(viewTitle); Spacer(); Text(notes.count,format:.number).monospacedDigit() } }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L("ملاحظاتي")).navigationBarTitleDisplayMode(.inline)
            .searchable(text:$query,prompt:L("ابحث في ملاحظاتك…"))
            .toolbar {
                ToolbarItem(placement:.topBarLeading) { filterMenu }
                ToolbarItem(placement:.topBarTrailing) { Button { settings = true } label: { Image(systemName:"gearshape") }.accessibilityLabel(L("الإعدادات")) }
            }
            .safeAreaInset(edge:.bottom) {
                    HStack(spacing:16) {
                        Label(store.saveLabel,systemImage:store.saveFailed ? "exclamationmark.triangle" : "checkmark.shield").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("save.status")
                        Spacer()
                        Button { if ["trash","archive"].contains(view) { view = "all" }; if let id = store.addNote(view:view) { path.append(id) } } label: { Label(L("ملاحظة جديدة"),systemImage:"square.and.pencil").font(.subheadline.bold()) }.buttonStyle(.borderedProminent).accessibilityIdentifier("new.note")
                    }.padding(.horizontal,20).padding(.vertical,12).background(.bar)
            }
            .navigationDestination(for:String.self) { id in NoteEditor(noteID:id) }
            .sheet(isPresented:$settings) { SettingsView() }
        }
    }
    private var filterMenu: some View {
        Menu {
            ForEach([("all",L("كل الملاحظات"),"note.text"),("pinned",L("المثبّتة"),"pin"),("archive",L("الأرشيف"),"archivebox"),("trash",L("المحذوفات"),"trash")],id:\.0) { item in Button { view = item.0; query = "" } label: { Label(item.1,systemImage:item.2) } }
            if !store.notebook.folders.isEmpty { Section(L("مجلداتي")) { ForEach(store.notebook.folders) { f in Button(f.name) { view = "folder:" + f.id; query = "" } } } }
            let tags = Array(Set(store.notebook.notes.filter { $0.status == "active" }.flatMap(\.tags))).sorted()
            if !tags.isEmpty { Section(L("الوسوم")) { ForEach(tags,id:\.self) { t in Button("# " + t) { view = "tag:" + t; query = "" } } } }
        } label: { Image(systemName:"line.3.horizontal.decrease") }.accessibilityLabel(L("تصفية الملاحظات"))
    }
    private var lockedView: some View {
        VStack(spacing:22) {
            Image(systemName:"leaf.fill").font(.system(size:58)).foregroundStyle(Color.waraqaGreen)
            Text(L("ورقة")).font(.system(size:42,weight:.bold,design:.serif))
            Text(L("أفكارك في مساحة مقفلة.")).foregroundStyle(.secondary)
            SecureField(L("كلمة مرور المساحة"),text:$password).textContentType(.password).textFieldStyle(.roundedBorder).accessibilityIdentifier("unlock.password").onSubmit { unlock() }
            Button(action:unlock) { HStack { if store.unlocking { ProgressView().tint(.white) }; Text(L("فتح مساحتي")).frame(maxWidth:.infinity) } }.buttonStyle(.borderedProminent).controlSize(.large).disabled(store.unlocking || password.isEmpty)
            if !unlockError.isEmpty { Text(unlockError).font(.caption).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently) }
            Text(L("كلمة المرور تبقى على جهازك. لا يمكن استعادتها.")).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(32).frame(maxWidth:440).frame(maxWidth:.infinity,maxHeight:.infinity).background(Color.waraqaCream)
    }
    private func unlock() {
        guard !store.unlocking else { return }; unlockError = ""
        Task { do { try await store.unlock(password:password); password = "" } catch { unlockError = error.localizedDescription } }
    }
    private var recoveryView: some View {
        VStack(spacing:20) {
            Image(systemName:"externaldrive.badge.exclamationmark").font(.largeTitle)
            Text(L("تعذّر فتح المساحة")).font(.title2.bold())
            Text(store.error ?? L("جارٍ التحميل…")).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(L("تصدير البيانات المحفوظة للفحص")) { do { recoveryExport = ExportDocument(bytes:try store.rawRecovery()); exportingRecovery = true } catch { store.error = error.localizedDescription } }.buttonStyle(.bordered)
            Button(L("استعادة النسخة المحلية السابقة")) { restoreConfirm = true }.buttonStyle(.bordered)
        }.padding(30)
        .fileExporter(isPresented:$exportingRecovery,document:recoveryExport,contentType:.json,defaultFilename:"alawynote-recovery.json") { _ in recoveryExport = nil }
        .confirmationDialog(L("استعادة آخر حفظ سابق؟ صدّر بيانات الفحص أولًا. قد تفقد آخر تعديل."),isPresented:$restoreConfirm,titleVisibility:.visible) { Button(L("استعادة النسخة السابقة"),role:.destructive) { do { try store.restorePrevious() } catch { store.error = error.localizedDescription } } }
    }
}
struct NoteRow: View {
    let note: Note
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack(alignment:.firstTextBaseline) { Text(note.displayTitle).font(.headline).lineLimit(2); Spacer(minLength:5); if note.pinned { Image(systemName:"pin.fill").font(.caption).foregroundStyle(Color.waraqaGreen) } }
            Text(note.body.isEmpty ? L("صفحة جديدة، وإمكانات كثيرة…") : note.body.replacingOccurrences(of:"[#*>`\\[\\]]",with:"",options:.regularExpression).replacingOccurrences(of:"\n",with:" ")).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            HStack { Text(note.date,format:.dateTime.day().month(.wide)).font(.caption2).foregroundStyle(.secondary); Spacer(); if let tag = note.tags.first { Text("# " + tag).font(.caption2).padding(.horizontal,8).padding(.vertical,4).background(Color.waraqaGreen.opacity(0.08),in:Capsule()).foregroundStyle(Color.waraqaGreen) } }
        }.padding(.vertical,10)
    }
}
