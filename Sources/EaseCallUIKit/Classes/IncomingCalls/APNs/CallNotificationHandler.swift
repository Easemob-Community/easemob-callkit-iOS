import UIKit
import UserNotifications

/// Forwards the host app's APNs registration and notification responses to EaseCallUIKit.
public final class CallNotificationHandler {
    public static let shared = CallNotificationHandler()
    private var deviceToken: Data?

    private init() {}

    /// Call from the main thread. Keep the host app as the notification center delegate.
    public func registerForNotifications(
        completion: @escaping (Bool, Error?) -> Void = { _, _ in }
    ) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted { UIApplication.shared.registerForRemoteNotifications() }
                completion(granted, error)
            }
        }
    }

    /// Forward application(_:didRegisterForRemoteNotificationsWithDeviceToken:).
    public func didRegister(deviceToken: Data) {
        self.deviceToken = deviceToken
        bindDeviceToken()
    }

    /// Call again after restoring or switching the signed-in IM account.
    public func bindDeviceToken() {
        guard let deviceToken else { return }
        ChatClient.shared().registerForRemoteNotifications(withDeviceToken: deviceToken) { error in
            if let error {
                consoleLogInfo("Could not bind the APNs token: \(error.errorDescription ?? "")", type: .error)
            }
        }
    }

    /// Returns true for a call notification the host should route through the call UI.
    /// The authenticated IM invite and the caller's confirmation are still required.
    @discardableResult
    public func handle(_ response: UNNotificationResponse) -> Bool {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return false }
        return handle(userInfo: response.notification.request.content.userInfo)
    }

    @discardableResult
    public func handle(userInfo: [AnyHashable: Any]) -> Bool {
        let custom: [String: Any]?
        if let json = userInfo["e"] as? String, let data = json.data(using: .utf8) {
            custom = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        } else {
            custom = userInfo["e"] as? [String: Any]
        }
        guard let custom,
              custom[kMsgType] as? String == kMsgTypeValue,
              custom[kAction] as? String == CALL_INVITE,
              let callID = custom[kCallId] as? String, !callID.isEmpty else { return false }

        DispatchQueue.main.async {
            CallKitManager.shared.openIncomingCallNotification(callID: callID)
        }
        return true
    }
}
