import EventKit

final class CalendarService {
    static let shared = CalendarService()
    private let store = EKEventStore()
    private var accessGranted = false
    private var accessChecked = false

    private init() {}

    func ensureAccess() async -> Bool {
        if accessChecked { return accessGranted }
        accessChecked = true

        if #available(macOS 14.0, *) {
            do {
                accessGranted = try await store.requestFullAccessToEvents()
            } catch {
                print("[Calendar] Access error: \(error.localizedDescription)")
                accessGranted = false
            }
        } else {
            accessGranted = await withCheckedContinuation { c in
                store.requestAccess(to: .event) { granted, _ in c.resume(returning: granted) }
            }
        }
        print("[Calendar] Access granted: \(accessGranted)")
        return accessGranted
    }

    func addEvent(_ event: CalendarEvent) async -> (Bool, String?) {
        guard await ensureAccess() else {
            print("[Calendar] No access — grant in System Settings > Privacy > Calendars")
            return (false, nil)
        }

        let ekEvent = EKEvent(eventStore: store)
        ekEvent.title = event.title
        ekEvent.startDate = event.startDate ?? Date()
        ekEvent.endDate = event.endDate ?? (event.startDate ?? Date()).addingTimeInterval(3600)
        ekEvent.location = event.location
        ekEvent.notes = event.notes
        ekEvent.calendar = store.defaultCalendarForNewEvents ?? store.calendars(for: .event).first
        ekEvent.addAlarm(EKAlarm(relativeOffset: -15 * 60))

        do {
            try store.save(ekEvent, span: .thisEvent, commit: true)
            print("[Calendar] Saved: \(event.title)")
            return (true, ekEvent.eventIdentifier)
        } catch {
            print("[Calendar] Save error: \(error.localizedDescription)")
            return (false, nil)
        }
    }

    func deleteEvent(identifier: String) async -> Bool {
        guard await ensureAccess() else { return false }
        guard let ekEvent = store.event(withIdentifier: identifier) else {
            print("[Calendar] Event not found: \(identifier)")
            return false
        }
        do {
            try store.remove(ekEvent, span: .thisEvent, commit: true)
            print("[Calendar] Deleted: \(identifier)")
            return true
        } catch {
            print("[Calendar] Delete error: \(error.localizedDescription)")
            return false
        }
    }
}
