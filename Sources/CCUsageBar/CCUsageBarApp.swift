import SwiftUI

@main
struct CCUsageBarApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            Text(store.menuBarLabel)
        }
        .menuBarExtraStyle(.window)
    }
}
