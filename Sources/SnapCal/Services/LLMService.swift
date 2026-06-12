import Foundation

struct LLMService {
    private static var apiKey: String { UserDefaults.standard.string(forKey: "openai_api_key") ?? "" }
    private static var endpoint: String { UserDefaults.standard.string(forKey: "openai_endpoint") ?? "https://api.deepseek.com/v1/chat/completions" }
    private static var model: String { UserDefaults.standard.string(forKey: "openai_model") ?? "deepseek-chat" }

    static func extractEvent(from text: String) async -> CalendarEvent {
        guard !apiKey.isEmpty, URL(string: endpoint) != nil else {
            return CalendarEvent(title: text)
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let prompt = """
        你是一个日程提取助手。请严格从文本中提取活动信息。
        当前时间：\(now)

        要求：
        - 只返回一个 JSON 对象，不要任何其他内容（不要 markdown 代码块，不要解释）。
        - 无明确结束时间时，结束时间 = 开始时间 + 1小时。
        - 无时间时，默认 09:00-10:00。
        - 无法提取时，title 返回原文，startTime 返回 null。

        {"title":"标题","startTime":"ISO8601","endTime":"ISO8601","location":"地点或null","notes":"备注或null"}
        """

        return await callLLM(system: prompt, user: text, fallbackTitle: text)
    }

    static func processCommand(_ command: String, on event: CalendarEvent) async -> CalendarEvent {
        guard !apiKey.isEmpty, URL(string: endpoint) != nil else {
            return event
        }

        let df = ISO8601DateFormatter()
        let info = """
        你是一个日历助手。请根据用户命令修改事件。

        当前事件：
        - 标题：\(event.title)
        - 开始：\(event.startDate.map { df.string(from: $0) } ?? "未设置")
        - 结束：\(event.endDate.map { df.string(from: $0) } ?? "未设置")
        - 地点：\(event.location ?? "无")
        - 备注：\(event.notes ?? "无")

        当前时间：\(df.string(from: Date()))
        """

        let prompt = """
        \(info)

        要求：
        - 只返回一个 JSON 对象，不要任何其他内容（不要 markdown 代码块，不要解释）。

        {"title":"修改后的标题","startTime":"ISO8601","endTime":"ISO8601","location":"地点或null","notes":"备注或null","action":"add"/"cancel"}

        规则：用户说"取消"→action="cancel"；说"确定"/"添加"/"OK"→action="add"；其他情况按指令修改对应字段后 action="add"。
        """

        return await callLLM(system: prompt, user: command, fallbackTitle: event.title)
    }

    private static func callLLM(system: String, user: String, fallbackTitle: String) async -> CalendarEvent {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "temperature": 0.1,
            "max_tokens": 500,
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return CalendarEvent(title: fallbackTitle)
        }
        request.httpBody = httpBody

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  var content = message["content"] as? String
            else {
                return CalendarEvent(title: fallbackTitle)
            }

            // Strip markdown code blocks if present (DeepSeek may wrap JSON in ```)
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.hasPrefix("```") {
                content = content
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard let contentData = content.data(using: .utf8) else {
                return CalendarEvent(title: fallbackTitle)
            }

            struct Resp: Codable {
                let title: String?
                let startTime: String?
                let endTime: String?
                let location: String?
                let notes: String?
                let action: String?
            }

            guard let parsed = try? JSONDecoder().decode(Resp.self, from: contentData) else {
                return CalendarEvent(title: fallbackTitle)
            }

            let df = ISO8601DateFormatter()
            df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            func parseDate(_ s: String?) -> Date? {
                guard let s else { return nil }
                return df.date(from: s) ?? ISO8601DateFormatter().date(from: s)
            }

            return CalendarEvent(
                title: parsed.title ?? fallbackTitle,
                startDate: parseDate(parsed.startTime),
                endDate: parseDate(parsed.endTime),
                location: parsed.location,
                notes: parsed.notes
            )
        } catch {
            print("[LLM] Error: \(error)")
            return CalendarEvent(title: fallbackTitle)
        }
    }
}
