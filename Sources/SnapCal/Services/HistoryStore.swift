import Foundation

struct HistoryItem: Codable, Identifiable, Equatable {
    var id: String { "\(addedAt.timeIntervalSince1970)" }
    let title: String
    let startTime: String?
    let endTime: String?
    let location: String?
    let notes: String?
    let addedAt: Date
    var eventIdentifier: String?

    var displayText: String {
        var lines = [title]
        let df = ISO8601DateFormatter()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"
        if let s = startTime, let start = df.date(from: s) { lines.append("开始: \(f.string(from: start))") }
        if let e = endTime, let end = df.date(from: e) { lines.append("结束: \(f.string(from: end))") }
        if let l = location { lines.append("地点: \(l)") }
        if let n = notes { lines.append("备注: \(n)") }
        return lines.joined(separator: "\n")
    }
}

struct HistoryStore {
    private static let key = "event_history"
    private static let maxItems = 20

    static func all() -> [HistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []
    }

    @discardableResult
    static func add(_ event: CalendarEvent, eventIdentifier: String? = nil) -> HistoryItem {
        let df = ISO8601DateFormatter()
        var item = HistoryItem(
            title: event.title,
            startTime: event.startDate.map { df.string(from: $0) },
            endTime: event.endDate.map { df.string(from: $0) },
            location: event.location,
            notes: event.notes,
            addedAt: Date(),
            eventIdentifier: eventIdentifier
        )
        var items = all()
        items.insert(item, at: 0)
        if items.count > maxItems { items = Array(items.prefix(maxItems)) }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return item
    }

    static func updateEventIdentifier(for item: HistoryItem, identifier: String) {
        var items = all()
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].eventIdentifier = identifier
        }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func remove(_ item: HistoryItem) {
        var items = all()
        items.removeAll { $0.id == item.id }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
