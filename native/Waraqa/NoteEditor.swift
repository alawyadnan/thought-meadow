import SwiftUI
import UniformTypeIdentifiers

struct NoteEditor: View {
    @EnvironmentObject private var store: NotebookStore
    @Environment(\.dismiss) private var dismiss
    let noteID: String
    @ViewState private var preview = false
    @ViewState private var focus = false
    @ViewState private var tagsEditor = false
    @ViewState private var tags = ""
    @ViewState private var export: ExportDocument?
    @ViewState private var exporting = false
    @ViewState private var plainExportConfirm = false
    @ViewState private var deletionConfirm = false
    private var note: Note? { store.note(noteID) }
    var body: some View {
        Group {
            if let note {
                VStack(spacing:0) {
                    if !focus {
                        Picker(L("وضع المحرر"),selection:$preview) { Text(L("كتابة")).tag(false); Text(L("معاينة")).tag(true) }.pickerStyle(.segmented).padding(.horizontal,22).padding(.vertical,12).disabled(note.status == "trash")
                    }
                    ScrollView {
                        VStack(alignment:.leading,spacing:17) {
                            if note.status == "trash" {
                                HStack { Text(L("هذه الملاحظة في المحذوفات.")).font(.caption); Spacer(); Button(L("استعادة")) { store.setStatus(noteID,"active") } }.padding(12).background(.orange.opacity(0.1),in:RoundedRectangle(cornerRadius:8))
                            }
                            if note.sample { Text(L("مساحة للتجربة")).font(.caption2).foregroundStyle(.secondary) }
                            TextField(L("عنوان الملاحظة"),text:Binding(get:{ store.note(noteID)?.title ?? "" },set:{ value in store.update(noteID) { $0.title = String(value.prefix(300)) } }),axis:.vertical).font(.system(.largeTitle,design:.serif).bold()).disabled(note.status == "trash").accessibilityIdentifier("note.title")
                            HStack { Text(note.date,format:.dateTime.day().month(.wide)); Text("·"); Text(AppLanguage.isArabic ? "\(note.words) كلمة" : "\(note.words) words") }.font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Text(note.tags.map { "# " + $0 }.joined(separator:"  ")).font(.caption).foregroundStyle(Color.waraqaGreen).lineLimit(2)
                                if note.status != "trash" { Button { tags = note.tags.joined(separator:"، "); tagsEditor = true } label: { Label(L("وسم"),systemImage:"plus") }.font(.caption).buttonStyle(.bordered) }
                                Spacer(minLength:0)
                            }
                            if preview || note.status == "trash" { NativePreview(body:note.body,readOnly:note.status == "trash") { index, checked in
                                store.update(noteID) { n in var lines = n.body.components(separatedBy:"\n"); guard lines.indices.contains(index), lines[index].count >= 6 else { return }; lines[index] = (checked ? "- [x] " : "- [ ] ") + lines[index].dropFirst(6); n.body = lines.joined(separator:"\n") }
                            }}
                            else {
                                TextEditor(text:Binding(get:{ store.note(noteID)?.body ?? "" },set:{ value in store.update(noteID) { $0.body = String(value.prefix(200_000)) } })).font(.body).lineSpacing(8).frame(minHeight:420).scrollContentBackground(.hidden).accessibilityLabel(L("محتوى الملاحظة")).accessibilityIdentifier("note.body")
                            }
                        }.padding(24)
                    }.scrollDismissesKeyboard(.interactively)
                    HStack { Label(store.saveLabel,systemImage:"checkmark.shield").font(.caption2).foregroundStyle(.secondary); Spacer(); if store.isEncrypted { Button { store.lock() } label: { Image(systemName:"lock") }.accessibilityLabel(L("قفل الآن")) } }.padding(.horizontal,22).padding(.vertical,12).background(Color.waraqaCream)
                }
                .navigationTitle(store.notebook.folders.first { $0.id == note.folder }?.name ?? L("ملاحظة"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.topBarTrailing) {
                        Menu {
                            if note.status != "trash" {
                                Button { store.update(noteID) { $0.pinned.toggle() } } label: { Label(note.pinned ? L("إلغاء التثبيت") : L("تثبيت"),systemImage:"pin") }
                                Menu(L("نقل إلى مجلد"),systemImage:"folder") {
                                    Button(L("دون مجلد")) { store.update(noteID) { $0.folder = "" } }
                                    ForEach(store.notebook.folders) { f in Button(f.name) { store.update(noteID) { $0.folder = f.id } } }
                                }
                                Button { store.setStatus(noteID,note.status == "archive" ? "active" : "archive"); dismiss() } label: { Label(note.status == "archive" ? L("إلغاء الأرشفة") : L("أرشفة"),systemImage:"archivebox") }
                            }
                            Button { if store.isEncrypted { plainExportConfirm = true } else { exportNote() } } label: { Label(L("تصدير Markdown"),systemImage:"square.and.arrow.up") }
                            Button { focus.toggle() } label: { Label(focus ? L("الخروج من التركيز") : L("وضع التركيز"),systemImage:"arrow.up.left.and.arrow.down.right") }
                            if note.status == "trash" { Button(role:.destructive) { deletionConfirm = true } label: { Label(L("حذف نهائي"),systemImage:"trash") } }
                            else { Button(role:.destructive) { store.setStatus(noteID,"trash"); dismiss() } label: { Label(L("نقل إلى المحذوفات"),systemImage:"trash") } }
                        } label: { Image(systemName:"ellipsis.circle") }.accessibilityLabel(L("خيارات الملاحظة"))
                    }
                }
                .onAppear { preview = note.status == "trash" || !note.body.isEmpty }
            } else { ContentUnavailableView(L("اختر ملاحظة"),systemImage:"note.text") }
        }
        .onDisappear { store.flush() }
        .sheet(isPresented:$tagsEditor) {
            NavigationStack { Form { TextField(L("افصل الوسوم بفاصلة"),text:$tags); Text(L("اترك الحقل فارغًا لإزالة الوسوم.")).font(.caption).foregroundStyle(.secondary) }.navigationTitle(L("وسوم الملاحظة")).toolbar { ToolbarItem(placement:.confirmationAction) { Button(L("حفظ")) { let list = tags.components(separatedBy:CharacterSet(charactersIn:",،")).map { String($0.trimmingCharacters(in:.whitespacesAndNewlines).prefix(40)) }.filter { !$0.isEmpty }; store.update(noteID) { $0.tags = Array(NSOrderedSet(array:list).array as? [String] ?? []).prefix(20).map { $0 } }; tagsEditor = false } }; ToolbarItem(placement:.cancellationAction) { Button(L("إلغاء")) { tagsEditor = false } } } }.presentationDetents([.medium])
        }
        .fileExporter(isPresented:$exporting,document:export,contentType:.plainText,defaultFilename:safeFilename) { result in if case .failure(let error) = result { store.error = error.localizedDescription }; export = nil }
        .confirmationDialog(L("سيكون ملف Markdown قابلًا للقراءة خارج حماية كلمة المرور."),isPresented:$plainExportConfirm,titleVisibility:.visible) { Button(L("تصدير دون تشفير")) { exportNote() } }
        .confirmationDialog(L("حذف الملاحظة نهائيًا؟ لا يمكن استعادتها من المحذوفات."),isPresented:$deletionConfirm,titleVisibility:.visible) { Button(L("حذف نهائي"),role:.destructive) { store.deletePermanently(noteID); dismiss() } }
    }
    private var safeFilename: String { String((note?.displayTitle ?? "note").replacingOccurrences(of:"[/\\\\:*?\"<>|]",with:"_",options:.regularExpression).prefix(100)) + ".md" }
    private func exportNote() { guard let note else { return }; export = ExportDocument(bytes:Data(("# " + note.displayTitle + "\n\n" + note.body + "\n").utf8)); exporting = true }
}
struct NativePreview: View {
    let bodyText: String
    let readOnly: Bool
    let onTask: (Int,Bool) -> Void
    init(body: String, readOnly: Bool, onTask: @escaping (Int,Bool) -> Void) { bodyText = body; self.readOnly = readOnly; self.onTask = onTask }
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            ForEach(Array(bodyText.components(separatedBy:"\n").enumerated()),id:\.offset) { index, line in
                if line.hasPrefix("- [ ] ") || line.lowercased().hasPrefix("- [x] ") {
                    let checked = line.lowercased().hasPrefix("- [x]")
                    Button { onTask(index,!checked) } label: { HStack(alignment:.firstTextBaseline,spacing:10) { Image(systemName:checked ? "checkmark.circle.fill" : "circle").foregroundStyle(Color.waraqaGreen); Text(String(line.dropFirst(6))).strikethrough(checked).foregroundStyle(checked ? .secondary : .primary); Spacer(minLength:0) } }.buttonStyle(.plain).disabled(readOnly).accessibilityValue(checked ? L("مكتملة") : L("غير مكتملة"))
                } else if line.hasPrefix("# ") { Text(String(line.dropFirst(2))).font(.title.bold()).padding(.top,8) }
                else if line.hasPrefix("## ") { Text(String(line.dropFirst(3))).font(.title3.bold()).padding(.top,15) }
                else if line.hasPrefix("### ") { Text(String(line.dropFirst(4))).font(.headline).padding(.top,8) }
                else if line.hasPrefix("> ") { Text(String(line.dropFirst(2))).font(.callout).foregroundStyle(.secondary).padding(14).frame(maxWidth:.infinity,alignment:.leading).background(Color.waraqaGreen.opacity(0.07),in:RoundedRectangle(cornerRadius:9)) }
                else if line.hasPrefix("- ") { HStack(alignment:.firstTextBaseline) { Text("•").foregroundStyle(Color.waraqaGreen); Text(String(line.dropFirst(2))); Spacer(minLength:0) } }
                else if line.isEmpty { Spacer(minLength:5).frame(height:5) }
                else { Text(line).textSelection(.enabled) }
            }
        }.font(.body).lineSpacing(7).frame(maxWidth:.infinity,alignment:.leading)
    }
}
