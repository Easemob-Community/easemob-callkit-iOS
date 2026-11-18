import UIKit

/// Incoming call presentation available to the current installation.
@objc public enum IncomingCallPresentation: Int {
    case inApp
    case liveCommunicationKit
    case appleCallKit
}

/// Optional system call UI. The IM invitation remains the source of call state.
protocol SystemIncomingCallPresenter: AnyObject {
    var presentation: IncomingCallPresentation { get }
    var activeCallID: String? { get }
    func report(_ call: CallInfo, callerName: String, isCurrent: Bool, completion: @escaping (Bool) -> Void)
    func requestAnswer()
    func inviteConfirmed()
    func setMuted(_ muted: Bool)
    func end(reason: CallEndReason)
    func connectMedia(whenReady: @escaping () -> Void)
}

extension SystemIncomingCallPresenter {
    func inviteConfirmed() {}
    func connectMedia(whenReady: @escaping () -> Void) { whenReady() }
}

extension CallKitManager {
    func configureSystemIncomingCalls() {
        #if EASE_CALL_LCK || EASE_CALL_APPLE_CALLKIT
        guard let presentation = configuredSystemPresentation else {
            voIPPushRegistry?.stop()
            voIPPushRegistry = nil
            systemCallPresenter?.end(reason: .cancel)
            systemCallPresenter = nil
            return
        }
        guard systemCallPresenter == nil else { return }

        if presentation == .liveCommunicationKit {
            #if EASE_CALL_LCK
            if #available(iOS 17.4, *) {
                systemCallPresenter = LiveCommunicationManager()
            }
            #endif
        } else {
            #if EASE_CALL_APPLE_CALLKIT
            systemCallPresenter = AppleCallKitPresenter()
            #endif
        }
        if let presenter = systemCallPresenter {
            voIPPushRegistry = VoIPPushRegistry(presenter: presenter)
        }
        #endif
    }

    private var configuredSystemPresentation: IncomingCallPresentation? {
        guard config.enableVOIP else { return nil }
        #if EASE_CALL_LCK
        if #available(iOS 17.4, *) {
            return .liveCommunicationKit
        }
        #endif
        #if EASE_CALL_APPLE_CALLKIT
        return config.enableAppleCallKit ? .appleCallKit : nil
        #else
        return nil
        #endif
    }

    func receiveVoIPInvitation(
        _ invitation: CallInfo, callerName: String, sentAt: Date?,
        presenter: SystemIncomingCallPresenter, completion: @escaping () -> Void
    ) {
        let client = ChatClient.shared()
        let callID = invitation.callId
        let hasRequiredFields = !callID.isEmpty && !invitation.callerId.isEmpty &&
            !invitation.callerDeviceId.isEmpty && !invitation.channelName.isEmpty
        let isFresh = sentAt.map { Date().timeIntervalSince($0) < Double(config.ringTimeOut) } ?? true
        let existing = callInfo?.state == .idle ? nil : callInfo
        let alreadyPresented = presenter.activeCallID == callID && existing?.callId == callID
        let canAdopt = existing == nil || (existing?.callId == callID && existing?.state == .ringing &&
            answeringIncomingCallID != callID)
        let isCurrent = alreadyPresented || (hasRequiredFields && isFresh && !endedIncomingCalls.contains(callID) &&
            invitation.callerId != client.currentUsername && canAdopt)
        let call = isCurrent ? (existing ?? receivedCalls[callID] ?? invitation) : invitation
        let isNew = isCurrent && existing == nil && receivedCalls[callID] == nil

        if isCurrent, existing == nil {
            call.state = .ringing
            call.calleeId = client.currentUsername ?? ""
            call.calleeDeviceId = client.getDeviceConfig(nil).deviceUUID ?? ""
            callInfo = call
            receivedCalls[callID] = call
            pendingSystemInviteID = callID
            startRingTimer(callId: callID)
        }

        presenter.report(call, callerName: callerName, isCurrent: isCurrent) { [weak self] reported in
            completion()
            guard let self, reported, isNew, self.callInfo?.callId == callID else { return }
            self.notifyIncomingCall(call)
        }
        if isCurrent {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.callInfo?.callId == callID else { return }
                client.applicationWillEnterForeground(UIApplication.shared)
                self.resumeSystemInviteSignaling()
            }
        }
    }

    func resumeSystemInviteSignaling() {
        let client = ChatClient.shared()
        guard client.isConnected, client.isLoggedIn, let account = client.currentUsername, !account.isEmpty,
              let call = callInfo, call.state == .ringing,
              pendingSystemInviteID == call.callId, sentSystemInviteAlertID != call.callId else { return }
        call.calleeId = account
        call.calleeDeviceId = client.getDeviceConfig(nil).deviceUUID ?? ""
        sentSystemInviteAlertID = call.callId
        calleeAnswerCaller(callId: call.callId, callerId: call.callerId, callerDeviceId: call.callerDeviceId)
    }

    func notifyIncomingCall(_ call: CallInfo) {
        for listener in listeners.allObjects {
            listener.onReceivedCall?(callType: call.type, userId: call.callerId, extensionInfo: call.extensionInfo)
        }
    }

    func openIncomingCallNotification(callID: String) {
        guard !endedIncomingCalls.contains(callID) else { return }
        pendingNotificationCall = (callID, Date().addingTimeInterval(Double(config.ringTimeOut)))
        presentPendingIncomingCall(matching: callID)
    }

    func endLiveCommunicationForVideo() {
        if systemCallPresenter?.presentation == .liveCommunicationKit {
            systemCallPresenter?.end(reason: .hangup)
        }
    }

    func rememberEndedIncomingCall(_ callID: String) {
        guard !callID.isEmpty, !endedIncomingCalls.contains(callID) else { return }
        endedIncomingCalls.append(callID)
        if endedIncomingCalls.count > 64 {
            endedIncomingCalls.removeFirst()
        }
    }
}

