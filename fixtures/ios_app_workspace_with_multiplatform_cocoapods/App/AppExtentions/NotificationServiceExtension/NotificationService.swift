import Foundation
import UserNotifications
import InterimSinglePod

final class NotificationService: UNNotificationServiceExtension {    

    // MARK: - Init
    
    override init() {
        super.init()
    }

    // MARK: - UNNotificationServiceExtension

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        print("Did Receive Notification")
    }
}
