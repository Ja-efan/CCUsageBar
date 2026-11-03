import SwiftUI

@main
struct NoonchiApp: App {
    @StateObject private var store = UsageStore()
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store, settings: settings)
        } label: {
            MenuBarLabel(store: store, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }
}
