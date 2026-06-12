import SwiftUI
import AppKit

class CommandPanelController {
    static let shared = CommandPanelController()
    private var window: NSWindow?
    private var lastFrame: NSRect = .zero
    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        if window == nil {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false
            )
            window?.title = "SnapCal"
            window?.isReleasedWhenClosed = false
            window?.level = .floating
        }
        window?.contentView = NSHostingView(rootView: CommandPanelView { [weak self] in self?.close() })
        positionWindow()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        if let w = window { lastFrame = w.frame; w.close() }
        window = nil
    }

    private func positionWindow() {
        guard let win = window else { return }
        let size = win.frame.size
        let posRaw = UserDefaults.standard.string(forKey: "panel_position") ?? "center"
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame: NSRect
        switch posRaw {
        case "mouse":
            let mouseLoc = NSEvent.mouseLocation
            var x = mouseLoc.x; var y = mouseLoc.y - size.height
            if x + size.width > screenFrame.maxX { x = screenFrame.maxX - size.width }
            if y < screenFrame.minY { y = screenFrame.minY }
            if x < screenFrame.minX { x = screenFrame.minX }
            frame = NSRect(x: x, y: y, width: size.width, height: size.height)
        case "topRight":
            frame = NSRect(x: screenFrame.maxX - size.width - 20, y: screenFrame.maxY - size.height - 20, width: size.width, height: size.height)
        case "right":
            frame = NSRect(x: screenFrame.maxX - size.width - 20, y: screenFrame.midY - size.height / 2, width: size.width, height: size.height)
        case "lastPosition":
            if lastFrame != .zero {
                frame = NSRect(x: lastFrame.origin.x, y: lastFrame.origin.y, width: size.width, height: size.height)
            } else {
                frame = NSRect(x: screenFrame.midX - size.width / 2, y: screenFrame.midY - size.height / 2, width: size.width, height: size.height)
            }
        default:
            frame = NSRect(x: screenFrame.midX - size.width / 2, y: screenFrame.midY - size.height / 2, width: size.width, height: size.height)
        }
        win.setFrame(frame, display: false)
    }
}

struct CommandPanelView: View {
    let onDismiss: () -> Void
    @State private var inputText: String = ""
    @State private var resultEvent: CalendarEvent?
    @State private var isLoading = false
    @State private var statusMessage: String = ""
    @State private var history: [HistoryItem] = HistoryStore.all()
    @State private var sourceHistoryItem: HistoryItem?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("输入活动信息").font(.headline)
                    Spacer()
                    Button(action: pasteFromClipboard) {
                        Text("粘贴").font(.caption)
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    if isLoading { ProgressView().scaleEffect(0.7) }
                }
                TextEditor(text: $inputText)
                    .font(.system(size: 14)).frame(height: 130)
                    .focused($isFocused)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                    .onAppear { pasteFromClipboard(); isFocused = true; refreshHistory() }
                if !statusMessage.isEmpty {
                    Text(statusMessage).font(.caption).foregroundColor(.secondary)
                }
            }
            .padding()

            HStack(spacing: 12) {
                Spacer()
                Button(action: { resetInput() }) { Text("清空") }
                    .disabled(isLoading || inputText.isEmpty)
                Button(action: { Task { await recognizeText() } }) {
                    Label("识别", systemImage: "sparkles")
                }
                .disabled(isLoading || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal).padding(.bottom, 4)

            Divider()

            if let event = resultEvent {
                ResultContentView(
                    event: event,
                    sourceHistoryItem: sourceHistoryItem,
                    isLoading: $isLoading,
                    statusMessage: $statusMessage,
                    onDismiss: onDismiss,
                    onSaved: { refreshHistory() }
                )
            } else {
                historyView
            }
        }
        .frame(width: 460)
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("最近记录").font(.caption).foregroundColor(.secondary)
                Spacer()
                if !history.isEmpty {
                    Button("清空记录") {
                        for item in history { HistoryStore.remove(item) }
                        refreshHistory()
                    }
                    .font(.caption).buttonStyle(.plain).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal).padding(.top, 8)

            if history.isEmpty {
                VStack {
                    Spacer()
                    Text("暂无记录，粘贴活动信息后点击「识别」")
                        .font(.caption).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(history) { item in
                        HistoryRow(item: item, onTap: { text in
                            inputText = text
                            sourceHistoryItem = item
                            resultEvent = nil
                            statusMessage = ""
                        })
                    }
                    .onDelete { idx in
                        for i in idx { HistoryStore.remove(history[i]) }
                        refreshHistory()
                    }
                }
                .listStyle(.plain).frame(maxHeight: .infinity)
            }
        }
    }

    private func resetInput() { inputText = ""; resultEvent = nil; statusMessage = ""; sourceHistoryItem = nil }
    private func pasteFromClipboard() {
        if let clip = NSPasteboard.general.string(forType: .string), !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            inputText = clip; sourceHistoryItem = nil
        }
    }
    private func recognizeText() async {
        isLoading = true; statusMessage = "识别中..."; resultEvent = nil
        let event = await LLMService.extractEvent(from: inputText.trimmingCharacters(in: .whitespacesAndNewlines))
        await MainActor.run {
            resultEvent = event; isLoading = false
            statusMessage = event.startDate != nil ? "✓ 识别完成" : "⚠️ 未能提取时间"
        }
    }
    private func refreshHistory() { history = HistoryStore.all() }
}

struct ResultContentView: View {
    let event: CalendarEvent
    let sourceHistoryItem: HistoryItem?
    @Binding var isLoading: Bool
    @Binding var statusMessage: String
    let onDismiss: () -> Void
    let onSaved: () -> Void
    @State private var currentEvent: CalendarEvent

    init(event: CalendarEvent, sourceHistoryItem: HistoryItem?, isLoading: Binding<Bool>, statusMessage: Binding<String>, onDismiss: @escaping () -> Void, onSaved: @escaping () -> Void) {
        self.event = event; self.sourceHistoryItem = sourceHistoryItem
        self._isLoading = isLoading; self._statusMessage = statusMessage
        self.onDismiss = onDismiss; self.onSaved = onSaved
        _currentEvent = State(initialValue: event)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("识别结果").font(.headline)
            Group {
                InfoRow(label: "标题", value: currentEvent.title)
                InfoRow(label: "开始", value: currentEvent.startDate.map { formatDate($0) } ?? "未识别")
                InfoRow(label: "结束", value: currentEvent.endDate.map { formatDate($0) } ?? "未识别")
                InfoRow(label: "地点", value: currentEvent.location ?? "无")
                InfoRow(label: "备注", value: currentEvent.notes ?? "无")
            }
            HStack {
                Button(action: { onDismiss() }) {
                    Label("取消", systemImage: "xmark.circle")
                }.disabled(isLoading)
                Spacer()
                Button(action: { Task { await addToCalendar() } }) {
                    Label("添加到日历", systemImage: "calendar.badge.plus")
                }
                .disabled(isLoading || currentEvent.startDate == nil)
                .keyboardShortcut(.return)
            }
        }
        .padding()
    }

    private func addToCalendar() async {
        isLoading = true; statusMessage = "添加到日历..."

        // If loaded from history and modified, delete old event first
        if let src = sourceHistoryItem, hasChanged(from: src) {
            if let oldId = src.eventIdentifier {
                statusMessage = "移除旧记录..."
                _ = await CalendarService.shared.deleteEvent(identifier: oldId)
            }
        }

        let (success, identifier) = await CalendarService.shared.addEvent(currentEvent)
        await MainActor.run {
            isLoading = false
            if success {
                // Update or create history entry with the new event identifier
                if let src = sourceHistoryItem {
                    // Remove old history entry and add updated one
                    HistoryStore.remove(src)
                }
                HistoryStore.add(currentEvent, eventIdentifier: identifier)
                statusMessage = "✓ 已添加到日历"
                onSaved()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { onDismiss() }
            } else {
                statusMessage = "⚠️ 添加失败"
            }
        }
    }

    private func hasChanged(from src: HistoryItem) -> Bool {
        if currentEvent.title != src.title { return true }
        let df = ISO8601DateFormatter()
        let newStart = currentEvent.startDate.map { df.string(from: $0) }
        let newEnd = currentEvent.endDate.map { df.string(from: $0) }
        if newStart != src.startTime { return true }
        if newEnd != src.endTime { return true }
        if currentEvent.location != src.location { return true }
        if currentEvent.notes != src.notes { return true }
        return false
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; return f.string(from: date)
    }
}

struct InfoRow: View {
    let label: String; let value: String
    var body: some View {
        HStack(alignment: .top) {
            Text(label).font(.caption).foregroundColor(.secondary).frame(width: 40, alignment: .leading)
            Text(value).font(.system(size: 13))
        }
    }
}

struct HistoryRow: View {
    let item: HistoryItem
    let onTap: (String) -> Void

    private var formattedStart: String? {
        guard let s = item.startTime, let start = ISO8601DateFormatter().date(from: s) else { return nil }
        let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm"
        return f.string(from: start)
    }

    var body: some View {
        Button(action: { onTap(item.displayText) }) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                if let start = formattedStart {
                    Text(start).font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
