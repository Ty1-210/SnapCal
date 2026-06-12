import CoreGraphics
import AppKit

struct HotkeyConfig: Codable {
    var keyCode: UInt32
    var modifiers: UInt32
}

final class HotkeyManager {
    static let shared = HotkeyManager()
    var onHotkey: (() -> Void)?
    private var eventTap: CFMachPort?
    private let defaults = UserDefaults.standard

    private init() {
        startTap()
        if defaults.data(forKey: "mainHotkey") == nil {
            let mods = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue
            let cfg = HotkeyConfig(keyCode: 50, modifiers: UInt32(mods))
            if let data = try? JSONEncoder().encode(cfg) { defaults.set(data, forKey: "mainHotkey") }
        }
    }

    deinit { stopTap() }

    func startTap() {
        stopTap()
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard type == .keyDown else { return Unmanaged.passUnretained(event) }
            let mgr = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
            mgr.handleEvent(event)
            return Unmanaged.passUnretained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        if let tap = eventTap {
            let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("[Hotkey] Event tap started")
        } else {
            print("[Hotkey] Event tap failed — needs Accessibility permission")
        }
    }

    func stopTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    private func handleEvent(_ event: CGEvent) {
        let cfg = currentHotkey()
        guard event.getIntegerValueField(.keyboardEventKeycode) == Int64(cfg.keyCode) else { return }
        // Compare only modifier flags, ignoring non-coalesced etc.
        let modMask = CGEventFlags.maskCommand.rawValue
                    | CGEventFlags.maskShift.rawValue
                    | CGEventFlags.maskAlternate.rawValue
                    | CGEventFlags.maskControl.rawValue
        let actualMods = event.flags.rawValue & modMask
        let expectedMods = UInt64(cfg.modifiers)
        if actualMods != expectedMods { return }

        DispatchQueue.main.async { self.onHotkey?() }
    }

    func register(keyCode: UInt32, modifiers: UInt32) {
        let cfg = HotkeyConfig(keyCode: keyCode, modifiers: modifiers)
        if let data = try? JSONEncoder().encode(cfg) { defaults.set(data, forKey: "mainHotkey") }
    }

    func currentHotkey() -> HotkeyConfig {
        if let data = defaults.data(forKey: "mainHotkey"),
           let cfg = try? JSONDecoder().decode(HotkeyConfig.self, from: data) { return cfg }
        let mods = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue
        return HotkeyConfig(keyCode: 50, modifiers: UInt32(mods))
    }

    func hotkeyDescription(_ cfg: HotkeyConfig) -> String {
        var parts: [String] = []
        let mods = CGEventFlags(rawValue: UInt64(cfg.modifiers))
        if mods.contains(.maskCommand) { parts.append("\u{2318}") }
        if mods.contains(.maskShift) { parts.append("\u{21E7}") }
        if mods.contains(.maskAlternate) { parts.append("\u{2325}") }
        if mods.contains(.maskControl) { parts.append("\u{2303}") }
        parts.append(keyCodeToString(cfg.keyCode))
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case 0: return "A"; case 1: return "S"; case 2: return "D"; case 3: return "F"
        case 4: return "H"; case 5: return "G"; case 6: return "Z"; case 7: return "X"
        case 8: return "C"; case 9: return "V"; case 11: return "B"
        case 12: return "Q"; case 13: return "W"; case 14: return "E"; case 15: return "R"
        case 16: return "Y"; case 17: return "T"
        case 18: return "1"; case 19: return "2"; case 20: return "3"; case 21: return "4"
        case 22: return "6"; case 23: return "5"
        case 24: return "="; case 25: return "9"; case 26: return "7"; case 27: return "-"
        case 28: return "8"; case 29: return "0"
        case 30: return "]"; case 31: return "O"; case 32: return "U"; case 33: return "["
        case 34: return "I"; case 35: return "P"
        case 37: return "L"; case 38: return "J"; case 39: return "'"; case 40: return "K"
        case 41: return ";"; case 42: return "\\"; case 43: return ","; case 44: return "/"
        case 45: return "N"; case 46: return "M"; case 47: return "."
        case 49: return "\u{2423}"; case 50: return "`"
        case 51: return "\u{232B}"; case 53: return "\u{238B}"
        case 123: return "\u{2190}"; case 124: return "\u{2192}"
        case 125: return "\u{2193}"; case 126: return "\u{2191}"
        default: return "K\(keyCode)"
        }
    }
}
