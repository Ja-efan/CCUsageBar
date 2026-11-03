import SwiftUI
import UsageCore

/// One window on one line: label, thin bar, percent, reset time.
struct WindowRow: View {
    let window: UsageWindow
    let stale: Bool
    @ObservedObject var settings: AppSettings

    var body: some View {
        let s = settings.strings
        let percent = Int(window.usedPercent.rounded())
        HStack(spacing: 8) {
            Text(s.windowLabel(window.kind))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 46, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    Capsule().fill(settings.barColor(for: window.usedPercent))
                        .frame(width: g.size.width * min(max(window.usedPercent, 0), 100) / 100)
                }
            }
            .frame(height: 4)
            .opacity(stale ? 0.45 : 1)
            Text("\(percent)%")
                .fontWeight(.medium)
                // Dimming text this much fails contrast; the header already says it's old.
                .foregroundStyle(stale ? Color.secondary : settings.textColor(for: window.usedPercent))
                .frame(width: 36, alignment: .trailing)
            resetText
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(width: 72, alignment: .trailing)
        }
        .font(.system(size: 12).monospacedDigit())
        .frame(height: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let s = settings.strings
        var parts = [s.windowLabel(window.kind), s.used(Int(window.usedPercent.rounded()))]
        if let date = window.resetsAt { parts.append(s.resetsAt(s.reset(ResetDisplay(date)))) }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder private var resetText: some View {
        if let date = window.resetsAt {
            // "42분 후" has to count down while the panel is open.
            TimelineView(.everyMinute) { context in
                Text(settings.strings.reset(ResetDisplay(date, now: context.date)))
            }
        } else {
            Text(window.resetText.map(ResetDisplay.trimmed) ?? "")
        }
    }
}

/// A service's header, its windows, and a line explaining any problem.
struct ProviderSection: View {
    let provider: any UsageProvider
    let state: ProviderState
    let paceModel: any PaceModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        let s = settings.strings
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    ProviderGlyph(provider: provider, style: settings.iconStyle,
                                  percent: state.usage.flatMap(MenuBarFormatter.autoWindow)?.usedPercent)
                    Text(provider.displayName)
                }
                .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(meta(s)).font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .padding(.bottom, 6)

            if let usage = state.usage {
                ForEach(usage.windows) { WindowRow(window: $0, stale: state.isStale, settings: settings) }
            }
            if !state.isStale, let usage = state.usage {
                PaceLine(usage: usage, provider: provider.id, paceModel: paceModel, settings: settings)
            }
            if let error = state.error {
                HStack(spacing: 6) {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                    Text(state.isStale ? "\(s.error(error)) · \(s.retryNext)" : s.error(error))
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            } else if state.usage == nil {
                Text(s.loading).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private func meta(_ s: Strings) -> String {
        if state.isStale, let usage = state.usage { return s.valueAt(s.clock(usage.fetchedAt)) }
        return state.usage?.plan ?? ""
    }
}

/// "이 속도면 3:10 PM에 5시간 한도 도달", only when a limit would come before its reset.
struct PaceLine: View {
    let usage: ProviderUsage
    let provider: ProviderID
    let paceModel: any PaceModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        TimelineView(.everyMinute) { context in
            let earliest = usage.windows
                .compactMap { w in paceModel.projectedLimit(for: w, provider: provider, now: context.date).map { (w, $0) } }
                .min { $0.1 < $1.1 }
            if let (window, date) = earliest {
                let s = settings.strings
                Text(s.pace(s.windowLabel(window.kind), ResetDisplay(date, now: context.date)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
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
                VStack(alignment: .leading, spacing: 0) {
                    if store.shown.isEmpty {
                        Text(s.noProviders)
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .padding(14)
                    }
                    ForEach(Array(store.shown.enumerated()), id: \.element.id) { i, provider in
                        if i > 0 { Divider() }
                        ProviderSection(provider: provider, state: store.states[provider.id] ?? ProviderState(),
                                        paceModel: store.paceModel, settings: settings)
                    }
                }
                .background(GeometryReader { g in
                    Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
                })
            }
            // A ScrollView has no natural height inside a menu bar panel, so size it
            // to the measured content (capped); otherwise it collapses to zero.
            .frame(height: min(max(store.contentHeight, 44), PanelView.maxContentHeight))
            .onPreferenceChange(ContentHeightKey.self) { store.contentHeight = $0 }

            Divider()

            // Footer stays visible while the content scrolls.
            HStack(spacing: 2) {
                if store.isLoading {
                    Text(s.refreshing)
                } else if let time = store.lastUpdated {
                    Text(s.updated(s.clock(time)))
                }
                Spacer()
                Button {
                    store.refresh()
                } label: {
                    if store.isLoading {
                        ProgressView().controlSize(.mini).frame(width: 24, height: 22)
                    } else {
                        Image(systemName: "arrow.clockwise").frame(width: 24, height: 22)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(store.isLoading)
                .help(s.refresh)
                .accessibilityLabel(s.refresh)
                Menu {
                    Button(s.settingsMenu) { SettingsWindow.show(store: store, settings: settings) }
                        .keyboardShortcut(",")
                    Button(s.showRawOutput) { RawOutputWindow.show(store: store, settings: settings) }
                    Divider()
                    Button(s.quit) { NSApp.terminate(nil) }
                        .keyboardShortcut("q")
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(s.more)
                .accessibilityLabel(s.more)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .padding(.vertical, 7)
        }
        .frame(width: 320)
    }
}
