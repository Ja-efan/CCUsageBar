import SwiftUI

@main
struct CCUsageBarApp: App {
    @StateObject private var store = UsageStore()
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store, settings: settings)
        } label: {
            Text(settings.menuBarLabel(snapshot: store.snapshot, hasLoaded: store.hasLoaded))
        }
        .menuBarExtraStyle(.window)
    }
}
