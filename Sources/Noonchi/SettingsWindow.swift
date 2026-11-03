import SwiftUI
import AppKit
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
            w.setContentSize(NSSize(width: 460, height: 620))
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

    private var s: Strings { settings.strings }

    var body: some View {
        Form {
            Section(s.general) {
                Picker(s.languageLabel, selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
            }

            Section {
                Toggle(s.session, isOn: settings.binding(for: .session))
                Toggle(s.weekAll, isOn: settings.binding(for: .week))
                ForEach(settings.knownModels, id: \.self) { name in
                    Toggle(s.weekModel(name), isOn: settings.binding(for: .model(name)))
                }
                if settings.knownModels.isEmpty {
                    Text(s.modelsHint).font(.caption).foregroundStyle(.secondary)
                }
                Picker(s.labelStyle, selection: $settings.labelStyle) {
                    Text(s.styleLabeled).tag(LabelStyle.labeled)
                    Text(s.styleCompact).tag(LabelStyle.compact)
                }
                LabeledContent(s.preview) {
                    Text(settings.menuBarLabel(snapshot: store.snapshot, hasLoaded: store.hasLoaded))
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
            } header: {
                Text(s.menuBar)
            } footer: {
                Text(s.menuBarHint).font(.caption).foregroundStyle(.secondary)
            }

            Section(s.barColor) {
                Picker(s.colorMode, selection: $settings.colorMode) {
                    Text(s.modeByUsage).tag(BarColorMode.byUsage)
                    Text(s.modeFixed).tag(BarColorMode.fixed)
                }
                .pickerStyle(.radioGroup)

                if settings.colorMode == .fixed {
                    HStack(spacing: 10) {
                        ForEach(AppSettings.presetColors, id: \.hex) { preset in
                            Button {
                                settings.barColorHex = preset.hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: preset.hex) ?? .gray)
                                    .frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(Color.primary,
                                        lineWidth: settings.barColorHex.uppercased() == preset.hex ? 2 : 0))
                            }
                            .buttonStyle(.plain)
                            .help(preset.name)
                        }
                        Spacer()
                        ColorPicker(s.customColor, selection: settings.barColorBinding, supportsOpacity: false)
                    }
                    Toggle(s.warnHigh, isOn: $settings.warnHighUsage)
                }

                // Live preview with sample values.
                VStack(spacing: 8) {
                    ForEach([25, 75, 95], id: \.self) { p in
                        HStack {
                            ProgressView(value: Double(p), total: 100).tint(settings.color(for: p))
                            Text("\(p)%").monospacedDigit().foregroundStyle(settings.color(for: p))
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .frame(minHeight: 560)
    }
}
