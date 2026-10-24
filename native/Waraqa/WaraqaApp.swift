import SwiftUI

// Name the property-wrapper type explicitly for compatibility across SDKs.
typealias ViewState<Value> = State<Value>

@main struct WaraqaApp: App {
    @StateObject private var store = NotebookStore()
    @AppStorage("appLanguage") private var language = "system"
    var body: some Scene {
        WindowGroup { WaraqaRoot(language:language).environmentObject(store).environment(\.layoutDirection,AppLanguage.isArabic ? .rightToLeft : .leftToRight).environment(\.locale,AppLanguage.locale).tint(.waraqaGreen) }
    }
}
extension Color {
    static let waraqaGreen = Color(red:0.19,green:0.36,blue:0.28)
    static let waraqaCream = Color(uiColor:.systemGroupedBackground)
}
