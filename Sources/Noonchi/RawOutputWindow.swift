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
    private var s: Strings { settings.strings }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView([.vertical, .horizontal]) {
                Text(store.snapshot.raw.isEmpty ? s.notYet : store.snapshot.raw)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
            }
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))

            HStack {
                Text(s.updated(store.snapshot.updatedAt.formatted(date: .omitted, time: .standard)))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(s.showInFinder) {
                    let path = ClaudeCodeProvider().debugFiles.cleaned
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                }
                Button(s.copy) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.snapshot.raw, forType: .string)
                }
                .disabled(store.snapshot.raw.isEmpty)
            }
        }
        .padding(14)
        .frame(minWidth: 420, minHeight: 300)
    }
}
