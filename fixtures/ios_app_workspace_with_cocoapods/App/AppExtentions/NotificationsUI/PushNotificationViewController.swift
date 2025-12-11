import UIKit
import UserNotifications
import UserNotificationsUI
import InterimSinglePod

final class PushNotificationViewController: UIViewController {
}

// MARK: - UNNotificationContentExtension

extension PushNotificationViewController: UNNotificationContentExtension {
    
    func didReceive(_ notification: UNNotification) {
        
    }
}
