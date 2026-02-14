import Foundation
import UserNotifications

protocol NotificationSending: Sendable {
    func requestAuthorizationIfNeeded() async
    func sendBreachNotification(projectName: String, metrics: ProjectMetrics, reasons: [BreachReason]) async
}

actor NotificationService: NotificationSending {
    private var didRequestAuthorization = false

    func requestAuthorizationIfNeeded() async {
        guard !didRequestAuthorization else {
            return
        }
        didRequestAuthorization = true
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    func sendBreachNotification(projectName: String, metrics: ProjectMetrics, reasons: [BreachReason]) async {
        let content = UNMutableNotificationContent()
        content.title = "GitTracker threshold breached"
        content.body = "\(projectName): +\(metrics.addedLines) -\(metrics.removedLines) (\(reasons.map(\.shortDescription).joined(separator: ", ")))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "gittracker-breach-\(projectName)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
