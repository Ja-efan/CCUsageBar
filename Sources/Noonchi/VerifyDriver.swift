#if NOONCHI_VERIFY
import AppKit
import UsageCore

/// Verification builds only (`-DNOONCHI_VERIFY`, never in a release). Lets the verify-noonchi
/// skill operate the running app without Accessibility permission: it polls a command file
/// and acts on the real status item and on controls through their accessibility actions.
@MainActor
enum VerifyDriver {
    private static let dir = ProcessInfo.processInfo.environment["NOONCHI_VERIFY_DIR"]
    private static var timer: Timer?
    private static weak var store: UsageStore?

    static func start(store: UsageStore) {
        guard dir != nil else { return }
        self.store = store
        let t = Timer(timeInterval: 0.1, repeats: true) { _ in Task { @MainActor in poll() } }
        // Common modes, so commands still run while a menu is tracking.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// The user may be working: give focus back unless a menu or the panel still needs it.
    private static func yieldFocus() {
        guard NSApp.isActive, !NSApp.windows.contains(where: { $0.isVisible && $0.level.rawValue >= 101 }) else { return }
        handFocusBack()
    }

    /// activate() and deactivate() don't release focus on macOS 14+. Hiding does, and the
    /// windows come back without taking it again.
    private static func handFocusBack() {
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { NSApp.unhideWithoutActivation() }
    }

    private static func poll() {
        // Mid-handback the windows are hidden; the command waits for them to return.
        guard !NSApp.isHidden, let dir, let line = try? String(contentsOfFile: dir + "/cmd", encoding: .utf8) else { return }
        try? FileManager.default.removeItem(atPath: dir + "/cmd")
        let parts = line.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ", maxSplits: 1).map(String.init)
        let reply = run(parts.first ?? "", parts.count > 1 ? parts[1] : "")
        if ["press", "toggle", "segment", "tab"].contains(parts.first ?? "") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { yieldFocus() }
        }
        let data = (try? JSONSerialization.data(withJSONObject: reply, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        try? data.write(to: URL(fileURLWithPath: dir + "/reply.tmp"))
        rename(dir + "/reply.tmp", dir + "/reply")
    }

    private static func run(_ command: String, _ argument: String) -> [String: Any] {
        switch command {
        case "ping":
            return ["ok": true, "pid": Int(getpid()), "bundle": Bundle.main.bundleIdentifier ?? "",
                    "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                    "home": NSHomeDirectory()]
        case "click-status":
            guard let button = statusButton else { return ["ok": false, "error": "no status button"] }
            button.performClick(nil)
            return ["ok": true]
        case "state":
            guard let store else { return ["ok": false, "error": "no store"] }
            return ["ok": true, "loading": store.isLoading, "active": NSApp.isActive, "services": store.shown.map { provider in
                let state = store.states[provider.id] ?? ProviderState()
                return ["id": provider.id.rawValue, "loading": state.isLoading, "stale": state.isStale,
                        "plan": state.usage?.plan ?? "", "error": state.error.map { String(describing: $0) } ?? "",
                        "windows": (state.usage?.windows ?? []).map { ["id": $0.id, "used": $0.usedPercent] }] as [String: Any]
            }]
        case "refresh":
            store?.refresh()
            return ["ok": true]
        case "yield":
            handFocusBack()
            return ["ok": true]
        case "close-window":
            for window in panels where window.title == argument { window.performClose(nil) }
            yieldFocus()
            return ["ok": true]
        case "windows":
            return ["ok": true, "status": statusButton?.window.map { rect($0.frame) } ?? [:], "windows": panels.map(describe)]
        case "tree":
            return ["ok": true, "tree": panels.map { node($0, depth: 0) }]
        case "press":
            for window in panels {
                if let element = find(window, label: argument) {
                    _ = element.perform(NSSelectorFromString("accessibilityPerformPress"))
                    return ["ok": true, "label": argument]
                }
            }
            return ["ok": false, "error": "no element labeled \(argument)"]
        case "toggle":
            // Toggles expose only 0/1, so find them by the text next to them.
            for window in panels {
                let all = flatten(window)
                guard let i = all.firstIndex(where: { label($0) == argument }),
                      let box = all[i...].first(where: { text($0, "accessibilityRole") == "AXCheckBox" })
                else { continue }
                _ = box.perform(NSSelectorFromString("accessibilityPerformPress"))
                return ["ok": true, "label": argument]
            }
            return ["ok": false, "error": "no toggle near \(argument)"]
        case "tab":
            // Tab labels have no press action; select through the tab control itself.
            for window in panels {
                guard let root = window.contentView, let tabs = views(root, of: NSTabView.self).first,
                      let item = tabs.tabViewItems.first(where: { $0.label == argument }) else { continue }
                tabs.selectTabViewItem(item)
                return ["ok": true, "label": argument]
            }
            return ["ok": false, "error": "no tab \(argument)"]
        case "segment":
            for window in panels {
                guard let root = window.contentView else { continue }
                for control in views(root, of: NSSegmentedControl.self) {
                    guard let i = (0..<control.segmentCount).first(where: { control.label(forSegment: $0) == argument }) else { continue }
                    control.selectedSegment = i
                    control.sendAction(control.action, to: control.target)
                    return ["ok": true, "label": argument]
                }
            }
            return ["ok": false, "error": "no segment \(argument)"]
        case "reveal":
            // A menu bar manager can push new items off screen. Move the item (the panel
            // anchors to it) to a visible spot so captures show what a user would see.
            guard let window = statusButton?.window, let screen = NSScreen.main else {
                return ["ok": false, "error": "no status window"]
            }
            let x = screen.frame.maxX - 760
            window.setFrameOrigin(NSPoint(x: x, y: window.frame.minY))
            for panel in panels { panel.setFrameOrigin(NSPoint(x: x, y: panel.frame.minY)) }
            return ["ok": true, "x": x]
        case "status-image":
            guard let image = statusButton?.image, let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]),
                  (try? png.write(to: URL(fileURLWithPath: argument))) != nil
            else { return ["ok": false, "error": "no status image"] }
            return ["ok": true, "path": argument, "template": image.isTemplate, "w": image.size.width, "h": image.size.height]
        default:
            return ["ok": false, "error": "unknown command \(command)"]
        }
    }

    private static var panels: [NSWindow] {
        NSApp.windows.filter { $0.isVisible && !String(describing: type(of: $0)).contains("StatusBar") }
    }

    private static var statusButton: NSStatusBarButton? {
        func find(_ v: NSView) -> NSStatusBarButton? {
            if let b = v as? NSStatusBarButton { return b }
            for s in v.subviews { if let b = find(s) { return b } }
            return nil
        }
        return NSApp.windows.lazy.compactMap { $0.contentView.flatMap(find) }.first
    }

    private static func rect(_ r: NSRect) -> [String: Double] {
        ["x": r.minX, "y": r.minY, "w": r.width, "h": r.height, "top": r.maxY]
    }

    private static func describe(_ w: NSWindow) -> [String: Any] {
        ["title": w.title, "number": w.windowNumber, "frame": rect(w.frame), "level": w.level.rawValue, "key": w.isKeyWindow]
    }

    private static func children(_ e: NSObject) -> [NSObject] {
        let s = NSSelectorFromString("accessibilityChildren")
        guard e.responds(to: s), let list = e.perform(s)?.takeUnretainedValue() as? [Any] else { return [] }
        return list.compactMap { $0 as? NSObject }
    }

    private static func text(_ e: NSObject, _ name: String) -> String? {
        let s = NSSelectorFromString(name)
        guard e.responds(to: s), let v = e.perform(s)?.takeUnretainedValue() else { return nil }
        return String(describing: v)
    }

    private static func label(_ e: NSObject) -> String {
        for name in ["accessibilityLabel", "accessibilityTitle", "accessibilityValue"] {
            if let t = text(e, name), !t.isEmpty { return t }
        }
        return ""
    }

    private static func node(_ e: NSObject, depth: Int) -> [String: Any] {
        var out: [String: Any] = ["role": text(e, "accessibilityRole") ?? "", "label": label(e)]
        if depth < 30 {
            let kids = children(e).map { node($0, depth: depth + 1) }
            if !kids.isEmpty { out["children"] = kids }
        }
        return out
    }

    private static func views<T: NSView>(_ view: NSView, of type: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { views($0, of: type) }
    }

    private static func flatten(_ e: NSObject) -> [NSObject] {
        [e] + children(e).flatMap(flatten)
    }

    private static func find(_ e: NSObject, label wanted: String) -> NSObject? {
        if label(e) == wanted, e.responds(to: NSSelectorFromString("accessibilityPerformPress")) { return e }
        for c in children(e) { if let f = find(c, label: wanted) { return f } }
        return nil
    }
}
#endif
