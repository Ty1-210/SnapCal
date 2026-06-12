import Foundation

struct CalendarEvent: Codable {
    var title: String
    var startDate: Date?
    var endDate: Date?
    var location: String?
    var notes: String?

    var formattedStart: String {
        guard let startDate else { return "未识别" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 HH:mm"
        return f.string(from: startDate)
    }

    var formattedEnd: String {
        guard let endDate else { return "未识别" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: endDate)
    }
}

struct LLMResponse: Codable {
    let title: String?
    let startTime: String?
    let endTime: String?
    let location: String?
    let notes: String?
}
