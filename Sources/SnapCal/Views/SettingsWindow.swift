import SwiftUI
import AppKit

struct PositionOption: Identifiable, Equatable {
    let key: String; let label: String; var id: String { key }
}

let positionOptions: [PositionOption] = [
    PositionOption(key: "center", label: "屏幕中央"),
    PositionOption(key: "mouse", label: "鼠标位置"),
    PositionOption(key: "topRight", label: "右上角"),
    PositionOption(key: "right", label: "右侧"),
    PositionOption(key: "lastPosition", label: "上次位置"),
]

class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    func show() {
        if window == nil {
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 360), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window?.title = "SnapCal 设置"; window?.isReleasedWhenClosed = false
        }
        window?.contentView = NSHostingView(rootView: SettingsView())
        window?.center(); window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func close() { window?.close() }
}

struct SettingsView: View {
    @State private var apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    @State private var endpoint = UserDefaults.standard.string(forKey: "openai_endpoint") ?? "https://api.deepseek.com/v1/chat/completions"
    @State private var model = UserDefaults.standard.string(forKey: "openai_model") ?? "deepseek-chat"
    @State private var selectedPosition: String = UserDefaults.standard.string(forKey: "panel_position") ?? "center"
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                Text("快捷键").font(.headline)
                SingleHotkeyRow(
                    label: "打开面板",
                    config: HotkeyManager.shared.currentHotkey(),
                    onChange: { HotkeyManager.shared.register(keyCode: $0.keyCode, modifiers: $0.modifiers) }
                )
                Text("需授予辅助功能权限才能使用全局快捷键").font(.caption).foregroundColor(.secondary)
            }
            Divider()
            Group {
                Text("面板位置").font(.headline)
                Picker("弹出位置", selection: $selectedPosition) {
                    ForEach(positionOptions) { opt in Text(opt.label).tag(opt.key) }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: selectedPosition) { _, newVal in UserDefaults.standard.set(newVal, forKey: "panel_position") }
            }
            Divider()
            Group {
                Text("API 配置").font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key").font(.caption).foregroundColor(.secondary)
                    SecureField("sk-...", text: $apiKey).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("端点").font(.caption).foregroundColor(.secondary)
                    TextField("https://api.deepseek.com/v1/chat/completions", text: $endpoint).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("模型").font(.caption).foregroundColor(.secondary)
                    TextField("deepseek-chat", text: $model).textFieldStyle(.roundedBorder)
                }
            }
            HStack {
                if saved { Text("已保存 ✓").foregroundColor(.green).font(.caption) }
                Spacer()
                Button("保存 API 配置") {
                    UserDefaults.standard.set(apiKey, forKey: "openai_api_key")
                    UserDefaults.standard.set(endpoint, forKey: "openai_endpoint")
                    UserDefaults.standard.set(model, forKey: "openai_model")
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                }
                .keyboardShortcut(.return)
            }
        }
        .padding().frame(width: 400)
    }
}

struct SingleHotkeyRow: View {
    let label: String; let onChange: (HotkeyConfig) -> Void
    @State private var isRecording = false
    @State private var displayText: String
    @State private var localMonitor: Any?

    init(label: String, config: HotkeyConfig, onChange: @escaping (HotkeyConfig) -> Void) {
        self.label = label; self.onChange = onChange
        _displayText = State(initialValue: HotkeyManager.shared.hotkeyDescription(config))
    }

    var body: some View {
        HStack {
            Text(label).font(.system(size: 12)).frame(width: 120, alignment: .leading)
            Text(displayText).font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color(nsColor: .controlColor)).cornerRadius(4)
            Button(isRecording ? "录制中..." : "录制") { startRecording() }.font(.system(size: 11))
        }
        .onDisappear { stopRecording() }
    }

    func startRecording() {
        isRecording = true; displayText = "按下组合键..."
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Convert NSEvent modifiers to CGEventFlags format
            var cgFlags: UInt64 = 0
            let nf = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if nf.contains(.command) { cgFlags |= CGEventFlags.maskCommand.rawValue }
            if nf.contains(.shift)   { cgFlags |= CGEventFlags.maskShift.rawValue }
            if nf.contains(.option)  { cgFlags |= CGEventFlags.maskAlternate.rawValue }
            if nf.contains(.control) { cgFlags |= CGEventFlags.maskControl.rawValue }
            let cfg = HotkeyConfig(keyCode: UInt32(event.keyCode), modifiers: UInt32(cgFlags & 0xFFFFFFFF))
            displayText = HotkeyManager.shared.hotkeyDescription(cfg)
            onChange(cfg); stopRecording(); return nil
        }
    }

    func stopRecording() {
        isRecording = false
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }
}
