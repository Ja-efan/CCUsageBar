import SwiftUI
import UsageCore

struct UsageRow: View {
    let title: String
    let percent: Int?
    let reset: String?
    @ObservedObject var settings: AppSettings

    var body: some View {
        let color = settings.color(for: percent)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(percent.map { "\($0)%" } ?? "–")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(color)
            }
            ProgressView(value: Double(percent ?? 0), total: 100).tint(color)
            if let reset {
                Text(settings.strings.resets(reset)).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Reports the natural height of the scrollable content.
private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct PanelView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: AppSettings
    static let maxContentHeight: CGFloat = 560

    private var s: Strings { settings.strings }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(s.title).font(.title3.bold())
                    UsageRow(title: s.session, percent: store.snapshot.sessionPercent,
                             reset: store.snapshot.sessionReset, settings: settings)
                    UsageRow(title: s.weekAll, percent: store.snapshot.weekPercent,
                             reset: store.snapshot.weekReset, settings: settings)
                    ForEach(store.snapshot.modelLimits) { m in
                        UsageRow(title: s.weekModel(m.name), percent: m.percent, reset: m.reset, settings: settings)
                    }

                    if let e = store.snapshot.error {
                        Label(s.error(e), systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }

                    Button {
                        RawOutputWindow.show(store: store, settings: settings)
                    } label: {
                        Label(s.showRawOutput, systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
                .padding(16)
                .background(GeometryReader { g in
                    Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
                })
            }
            // A ScrollView has no natural height inside a menu bar panel, so size it
            // to the measured content (capped); otherwise it collapses to zero.
            .frame(height: min(max(store.contentHeight, 120), PanelView.maxContentHeight))
            .onPreferenceChange(ContentHeightKey.self) { store.contentHeight = $0 }

            Divider()

            // Footer stays visible while the content scrolls.
            HStack(spacing: 8) {
                if store.isLoading {
                    ProgressView().controlSize(.small)
                    Text(s.loading).font(.caption)
                } else if store.hasLoaded {
                    Text(s.updated(store.snapshot.updatedAt.formatted(date: .omitted, time: .shortened)))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    SettingsWindow.show(store: store, settings: settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .help(s.settings)
                Button(s.refresh) { store.refresh() }.disabled(store.isLoading)
                Button(s.quit) { NSApp.terminate(nil) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 340)
    }
}
