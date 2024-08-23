import Foundation
import UserNotifications
import UIKit

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    // MARK: - Request Permission
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    // MARK: - Schedule Video Export Completion Notification
    
    func scheduleVideoExportNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Video Ready! 🎉"
        content.body = "Your 2025 Mapped video is ready to share"
        content.sound = .default
        content.badge = 1
        
        // Trigger immediately (will fire when export completes)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "videoExportComplete",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            } else {
                print("Notification scheduled")
            }
        }
    }
    
    // MARK: - Cancel Pending Notifications
    
    func cancelVideoExportNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["videoExportComplete"])
    }
    
    // MARK: - Clear Badge

    func clearBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0)
        } else {
            // iOS 15 fallback
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
}
