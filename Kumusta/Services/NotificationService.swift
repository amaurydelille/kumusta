import Foundation
import UserNotifications

struct NotificationPreferencesSnapshot: Codable, Equatable, Sendable {
    let remindersEnabled: Bool
    let reminderHour: Int
    let reminderMinute: Int
    let streakWarningEnabled: Bool
}

@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    private enum Keys {
        static let remindersEnabled = "kumusta.notifications.reminders-enabled.v1"
        static let reminderHour = "kumusta.notifications.reminder-hour.v1"
        static let reminderMinute = "kumusta.notifications.reminder-minute.v1"
        static let streakWarningEnabled = "kumusta.notifications.streak-warning.v1"
        static let reminderInvitationSeen = "kumusta.notifications.invitation-seen.v1"
    }

    private let defaults: UserDefaults

    var remindersEnabled: Bool {
        get { defaults.object(forKey: Keys.remindersEnabled) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Keys.remindersEnabled)
            if newValue { scheduleDailyReminder() }
            else { cancelDailyReminder() }
        }
    }

    var reminderHour: Int {
        get { defaults.integer(forKey: Keys.reminderHour).clamped(to: 0...23, fallback: 9) }
        set { defaults.set(newValue, forKey: Keys.reminderHour); scheduleDailyReminder() }
    }

    var reminderMinute: Int {
        get { defaults.integer(forKey: Keys.reminderMinute).clamped(to: 0...59, fallback: 0) }
        set { defaults.set(newValue, forKey: Keys.reminderMinute); scheduleDailyReminder() }
    }

    var streakWarningEnabled: Bool {
        get { defaults.object(forKey: Keys.streakWarningEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.streakWarningEnabled) }
    }

    func snapshot() -> NotificationPreferencesSnapshot {
        NotificationPreferencesSnapshot(
            remindersEnabled: remindersEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            streakWarningEnabled: streakWarningEnabled
        )
    }

    func replace(with snapshot: NotificationPreferencesSnapshot) {
        defaults.set(snapshot.remindersEnabled, forKey: Keys.remindersEnabled)
        defaults.set(snapshot.reminderHour.clamped(to: 0...23, fallback: 9), forKey: Keys.reminderHour)
        defaults.set(snapshot.reminderMinute.clamped(to: 0...59, fallback: 0), forKey: Keys.reminderMinute)
        defaults.set(snapshot.streakWarningEnabled, forKey: Keys.streakWarningEnabled)
        if snapshot.remindersEnabled {
            scheduleDailyReminder()
        } else {
            cancelDailyReminder()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.remindersEnabled) == nil {
            defaults.set(true, forKey: Keys.remindersEnabled)
        }
    }

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func shouldInviteAfterLesson() async -> Bool {
        guard !defaults.bool(forKey: Keys.reminderInvitationSeen) else { return false }
        return await center.notificationSettings().authorizationStatus == .notDetermined
    }

    func markReminderInvitationSeen() {
        defaults.set(true, forKey: Keys.reminderInvitationSeen)
    }

    func scheduleDailyReminder() {
        guard remindersEnabled else { return }

        center.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])

        let content = UNMutableNotificationContent()
        content.title = Self.dailyReminderTitle
        content.body = L("A few minutes of Vietnamese listening keeps your streak alive.")
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-reminder",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    /// Pending reminders keep the text they were scheduled with. Re-create an
    /// already scheduled reminder whose text is not in the current language;
    /// never schedule one the learner did not already have.
    func relocalizePendingReminder() async {
        let pending = await center.pendingNotificationRequests()
        guard let reminder = pending.first(where: { $0.identifier == "daily-reminder" }),
              reminder.content.title != Self.dailyReminderTitle
        else { return }
        scheduleDailyReminder()
    }

    private static var dailyReminderTitle: String { L("Time for your ear training") }

    func scheduleStreakWarning(streak: Int) {
        guard streakWarningEnabled, streak > 0 else { return }

        center.removePendingNotificationRequests(withIdentifiers: ["streak-warning"])

        let content = UNMutableNotificationContent()
        if streak >= 7 {
            content.title = L("Your %lld-day streak is at risk", streak)
            content.body = L("You have %lld streak freezes. Complete a lesson before midnight to keep your flame.", streak)
        } else {
            content.title = L("Don't lose your streak")
            content.body = L("A quick lesson now keeps your %lld-day streak going.", streak)
        }
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        var components = DateComponents()
        components.hour = 20
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak-warning",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func notifyAchievementUnlocked(_ achievement: Achievement) {
        let content = UNMutableNotificationContent()
        content.title = L("Badge earned: %@", achievement.title)
        content.body = L("You've reached a new milestone. Check your profile.")
        content.sound = .default
        content.interruptionLevel = .active

        let request = UNNotificationRequest(
            identifier: "achievement-\(achievement.kind.rawValue)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])
    }

    func cancelStreakWarning() {
        center.removePendingNotificationRequests(withIdentifiers: ["streak-warning"])
    }

    func clearAll() {
        center.removeAllPendingNotificationRequests()
    }

    func resetForAccountDeletion() {
        clearAll()
        defaults.removeObject(forKey: Keys.remindersEnabled)
        defaults.removeObject(forKey: Keys.reminderHour)
        defaults.removeObject(forKey: Keys.reminderMinute)
        defaults.removeObject(forKey: Keys.streakWarningEnabled)
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>, fallback: Int) -> Int {
        range.contains(self) ? self : fallback
    }
}
