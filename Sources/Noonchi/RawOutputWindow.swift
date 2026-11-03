import SwiftUI
import AppKit
import UsageCore

/// Shows the last captured `/usage` output in its own window.
///
/// This lives outside the menu bar panel on purpose: a MenuBarExtra window grows
/// when content expands but does not shrink back, which left blank space at the top.
@MainActor
enum RawOutputWindow {
    private static var window: NSWindow?

    static func show(store: UsageStore, settings: AppSettings) {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: RawOutputView(store: store, settings: settings)))

            w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            w.setContentSize(NSSize(width: 640, height: 520))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        window?.title = settings.strings.rawOutputTitle
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct RawOutputView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: AppSettings
    @State private var selected: ProviderID?
    private var s: Strings { settings.strings }

    private var provider: (any UsageProvider)? {
        store.shown.first { $0.id == selected } ?? store.shown.first
    }

    var body: some View {
        let state = provider.flatMap { store.states[$0.id] } ?? ProviderState()
        VStack(alignment: .leading, spacing: 10) {
            if store.shown.count > 1 {
                Picker("", selection: Binding(get: { provider?.id }, set: { selected = $0 })) {
                    ForEach(store.shown, id: \.id) { Text($0.displayName).tag(Optional($0.id)) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            ScrollView([.vertical, .horizontal]) {
                Text(state.raw.isEmpty ? s.notYet : state.raw)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
            }
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))

            HStack {
                if let time = state.lastAttempt {
                    Text(s.updated(time.formatted(date: .omitted, time: .standard)))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                // Only Claude's capture is saved to disk.
                if let claude = provider as? ClaudeCodeProvider {
                    Button(s.showInFinder) {
                        NSWorkspace.shared.selectFile(claude.debugFiles.cleaned, inFileViewerRootedAtPath: "")
                    }
                }
                Button(s.copy) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(state.raw, forType: .string)
                }
                .disabled(state.raw.isEmpty)
            }
        }
        .padding(14)
        .frame(minWidth: 420, minHeight: 300)
    }
}
