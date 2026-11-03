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

            Section(s.colors) {
                Toggle(isOn: $settings.highlightHigh) {
                    Text(s.highlightHigh)
                    Text(s.highlightHint)
                }
                LabeledContent(s.barColor) {
                    HStack(spacing: 8) {
                        swatch(nil, Color.primary.opacity(0.6), help: s.systemColor)
                        ForEach(AppSettings.presetColors, id: \.hex) { preset in
                            swatch(preset.hex, Color(hex: preset.hex) ?? .gray, help: preset.name)
                        }
                        ColorPicker("", selection: settings.barColorBinding, supportsOpacity: false)
                            .labelsHidden()
                    }
                }
            }

            Section(s.general) {
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

    private func swatch(_ hex: String?, _ color: Color, help: String) -> some View {
        let selected = settings.barColorHex?.uppercased() == hex?.uppercased()
        return Button {
            settings.barColorHex = hex
        } label: {
            Circle().fill(color)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color.primary, lineWidth: selected ? 2 : 0).padding(-3))
        }
        .buttonStyle(.plain)
        .help(help)
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
                        Text(path.map { "\(Self.abbreviate($0)) · \(s.every(provider.refreshInterval))" } ?? s.notInstalled)
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
            Text(MenuBarFormatter.shortLabel(forID: window))
                .font(.system(size: 11))
                .padding(.horizontal, 8).padding(.vertical, 2)
                .foregroundStyle(on ? Color(nsColor: .windowBackgroundColor) : .primary)
                .background(on ? Color.primary : .clear, in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.25), lineWidth: on ? 0 : 0.5))
        }
        .buttonStyle(.plain)
    }

    /// "/Users/me/.local/bin/claude" → "~/.local/bin/claude"
    private static func abbreviate(_ path: String) -> String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
