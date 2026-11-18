#if !SWIFT_PACKAGE || EASE_CALL_LCK || EASE_CALL_APPLE_CALLKIT
import UIKit
import PushKit

final class VoIPPushRegistry: NSObject, PKPushRegistryDelegate {
    private let registry = PKPushRegistry(queue: .main)
    private weak var presenter: SystemIncomingCallPresenter?
    private(set) var token: Data?

    init(presenter: SystemIncomingCallPresenter) {
        self.presenter = presenter
        super.init()
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
    }

    func bindToken() {
        guard let token else { return }
        ChatClient.shared().registerPushKitToken(token) { error in
            if let error {
                consoleLogInfo("Could not bind the VoIP token: \(error.errorDescription ?? "")", type: .error)
            }
        }
    }

    func stop() {
        registry.desiredPushTypes = []
        registry.delegate = nil
        invalidateToken()
    }

    private func invalidateToken() {
        guard token != nil else { return }
        token = nil
        CallKitManager.shared.config.onVoIPTokenChange?(nil)
        ChatClient.shared().unRegisterPushKitToken { error in
            if let error {
                consoleLogInfo("Could not unbind the VoIP token: \(error.errorDescription ?? "")", type: .error)
            }
        }
    }

    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        if token != credentials.token {
            token = credentials.token
            CallKitManager.shared.config.onVoIPTokenChange?(token)
        }
        bindToken()
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        invalidateToken()
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP, let presenter else {
            completion()
            return
        }
        let data = payload.dictionaryPayload
        let custom = data["e"] as? [String: Any] ?? [:]
        let callerID = data["f"] as? String ?? ""
        let call = CallInfo(
            callId: custom[kCallId] as? String ?? "",
            callerId: callerID,
            callerDeviceId: custom[kCallerDevId] as? String ?? "",
            channelName: custom[kChannelName] as? String ?? "",
            type: CallType(rawValue: custom[kCallType] as? UInt ?? 0) ?? .singleAudio,
            extensionInfo: custom[kExt] as? [String: Any]
        )
        call.inviteMessageId = data["m"] as? String ?? ""
        let group = custom[kCallKitGroupExt] as? [String: Any]
        call.groupId = data["g"] as? String ?? group?["groupId"] as? String
        call.groupName = group?["groupName"] as? String
        call.groupAvatar = group?["groupAvatar"] as? String
        let callerName = (custom["callerNickname"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? callerID
        let sentAt = (custom[kTs] as? NSNumber).map {
            Date(timeIntervalSince1970: $0.doubleValue / 1000)
        }
        CallKitManager.shared.receiveVoIPInvitation(
            call, callerName: callerName, sentAt: sentAt, presenter: presenter, completion: completion
        )
    }
}
#endif
