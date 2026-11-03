import SwiftUI
import AppKit
import UsageCore

/// The menu bar content, drawn into an image. MenuBarExtra strips colors from
/// text, so an image is the only way to show the 80%/95% highlight.
struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: AppSettings
    /// Bumped when the system appearance changes, to redraw in the right colors.
    @State private var appearanceToken = 0

    var body: some View {
        let items = settings.menuBarItems(for: store)
        Group {
            if items.isEmpty {
                Image(systemName: "gauge.with.dots.needle.33percent")
            } else {
                Image(nsImage: render(items))
                    .accessibilityLabel(items.map(\.text).joined(separator: ", "))
            }
        }
        .onReceive(DistributedNotificationCenter.default().publisher(
            for: Notification.Name("AppleInterfaceThemeChangedNotification"))) { _ in appearanceToken += 1 }
    }

    private func render(_ items: [MenuBarItem]) -> NSImage {
        _ = appearanceToken
        // Without a highlight, a template image lets the system pick the color.
        let template = items.allSatisfy { $0.highlight == .none }
        let base: Color = template ? .black : (Self.menuBarIsDark ? .white : .black)
        let content = MenuBarContent(items: items, style: settings.iconStyle, base: base)
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = template
        return image
    }

    /// The menu bar can be dark while the app is light (wallpaper tinting), so ask
    /// the status bar button itself.
    private static var menuBarIsDark: Bool {
        func find(_ v: NSView) -> NSView? {
            if v is NSStatusBarButton { return v }
            for s in v.subviews { if let b = find(s) { return b } }
            return nil
        }
        let button = NSApp.windows.lazy.compactMap { $0.contentView.flatMap(find) }.first
        let appearance = button?.effectiveAppearance ?? NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

private struct MenuBarContent: View {
    let items: [MenuBarItem]
    let style: IconStyle
    let base: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.providerID) { item in
                let color = AppSettings.color(for: item.highlight) ?? base
                HStack(spacing: 3) {
                    if let provider = Providers.all.first(where: { $0.id == item.providerID }) {
                        ProviderGlyph(provider: provider, style: style, percent: item.ringPercent)
                    }
                    Text(item.text)
                }
                .foregroundStyle(color)
            }
        }
        .font(.system(size: 13).monospacedDigit())
        .fixedSize()
        .padding(.vertical, 1)
    }
}

/// A service's icon in one of the three styles.
struct ProviderGlyph: View {
    let provider: any UsageProvider
    let style: IconStyle
    var percent: Double?

    var body: some View {
        switch style {
        case .symbol:
            Image(systemName: provider.symbolName)
                .font(.system(size: 11, weight: .semibold))
        case .monogram:
            Text(provider.monogram)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 13, height: 13)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(lineWidth: 1.2))
        case .ring:
            ZStack {
                Circle().stroke(lineWidth: 1.6).opacity(0.3)
                Circle()
                    .trim(from: 0, to: min(max((percent ?? 0) / 100, 0), 1))
                    .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(provider.monogram).font(.system(size: 7, weight: .bold))
            }
            .frame(width: 14, height: 14)
        }
    }
}
