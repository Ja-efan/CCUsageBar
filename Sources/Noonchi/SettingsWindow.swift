import SwiftUI
import AppKit
import ServiceManagement
import UsageCore

/// Settings live in their own window so the menu bar panel never changes size.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show(store: UsageStore, settings: AppSettings) {
        if window == nil {
            let view = SettingsView(store: store, settings: settings)
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        window?.title = settings.strings.settingsTitle
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralSettings(settings: settings)
                .tabItem { Label(settings.strings.general, systemImage: "gearshape") }
            ServiceSettings(store: store, settings: settings)
                .tabItem { Label(settings.strings.services, systemImage: "square.stack") }
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GeneralSettings: View {
    @ObservedObject var settings: AppSettings
    /// Read from the system; the app doesn't store it.
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var needsApproval = SMAppService.mainApp.status == .requiresApproval

    private var s: Strings { settings.strings }

    private var minutes: Binding<Int> {
        Binding(get: { settings.refreshInterval.minutes },
                set: { settings.refreshInterval = RefreshInterval(minutes: $0) })
    }

    var body: some View {
        Form {
            Section(s.menuBar) {
                Picker(s.menuBarMode, selection: $settings.menuBarMode) {
                    Text(s.modeAuto).tag(MenuBarMode.auto)
                    Text(s.modeCustom).tag(MenuBarMode.custom)
                }
                .pickerStyle(.segmented)
                if settings.menuBarMode == .custom {
                    Text(s.customHint).font(.caption).foregroundStyle(.secondary)
                }
                Toggle(isOn: $settings.labeled) {
                    Text(s.labels)
                    Text(s.labelsHint)
                }
                Picker(s.iconStyle, selection: $settings.iconStyle) {
                    Text(s.iconSymbol).tag(IconStyle.symbol)
                    Text(s.iconMonogram).tag(IconStyle.monogram)
                    Text(s.iconRing).tag(IconStyle.ring)
                }
            }

            Section {
                LabeledContent {
                    HStack(spacing: 6) {
                        TextField("", value: minutes, format: .number.grouping(.never))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 48)
                        Text(s.minutesUnit)
                        Stepper("", value: minutes, in: RefreshInterval.range)
                            .labelsHidden()
                    }
                } label: {
                    Text(s.refreshEvery)
                    Text(s.refreshHint)
                }
            }

            Section(s.colors) {
                Toggle(isOn: $settings.highlightHigh) {
                    Text(s.highlightHigh)
                    Text(s.highlightHint)
                }
                Picker(s.barColor, selection: $settings.barColorHex) {
                    Text(s.systemColor).tag(String?.none)
                    ForEach(barColorChoices, id: \.hex) { choice in
                        Label { Text(choice.name) } icon: { Image(nsImage: Self.dot(choice.hex)) }
                            .tag(Optional(choice.hex))
                    }
                }
            }

            Section {
                Picker(s.languageLabel, selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle(s.launchAtLogin, isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                if needsApproval {
                    Button(s.approveInSystemSettings) { SMAppService.openSystemSettingsLoginItems() }
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }

    /// Presets, plus a color kept from v0.3 that isn't one of them.
    private var barColorChoices: [(name: String, hex: String)] {
        let presets = AppSettings.presetColors
        guard let hex = settings.barColorHex, !presets.contains(where: { $0.hex.caseInsensitiveCompare(hex) == .orderedSame })
        else { return presets }
        return presets + [(s.other, hex)]
    }

    /// Menus render SwiftUI shapes poorly; a small image keeps the color.
    private static func dot(_ hex: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
            (NSColor(Color(hex: hex) ?? .gray)).setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        return image
    }

    private func setLaunchAtLogin(_ on: Bool) {
        let service = SMAppService.mainApp
        try? on ? service.register() : service.unregister()
        launchAtLogin = service.status == .enabled
        needsApproval = service.status == .requiresApproval
    }
}

private struct ServiceSettings: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: AppSettings

    private var s: Strings { settings.strings }

    var body: some View {
        Form {
            ForEach(Providers.all, id: \.id) { provider in
                let path = provider.locateExecutable()
                Section {
                    Toggle(isOn: Binding(get: { settings.isEnabled(provider.id) && path != nil },
                                         set: { settings.setEnabled(provider.id, $0); store.refresh(provider) })) {
                        HStack(spacing: 6) {
                            Circle().fill(path != nil ? Color.green : Color.secondary.opacity(0.4))
                                .frame(width: 7, height: 7)
                            Text(provider.displayName)
                        }
                        Text(path.map { "\(Self.abbreviate($0)) · \(s.every(settings.refreshInterval))" } ?? s.notInstalled)
                    }
                    .disabled(path == nil)

                    if settings.menuBarMode == .custom, path != nil, settings.isEnabled(provider.id) {
                        LabeledContent(s.menuBarItems) {
                            let choices = settings.choices(for: provider.id)
                            if choices.isEmpty {
                                Text(s.afterFirstRefresh).font(.caption).foregroundStyle(.secondary)
                            } else {
                                HStack(spacing: 6) {
                                    ForEach(choices, id: \.self) { window in
                                        chip(provider.id, window)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func chip(_ id: ProviderID, _ window: String) -> some View {
        let on = settings.isSelected(id, window)
        return Button {
            settings.toggle(id, window)
        } label: {
            Text(s.windowLabel(id: window))
                .font(.system(size: 11))
                .padding(.horizontal, 8).padding(.vertical, 2)
                .foregroundStyle(on ? Color(nsColor: .windowBackgroundColor) : .primary)
                .background(on ? Color.primary : .clear, in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.25), lineWidth: on ? 0 : 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// "/Users/me/.local/bin/claude" → "~/.local/bin/claude"
    private static func abbreviate(_ path: String) -> String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
