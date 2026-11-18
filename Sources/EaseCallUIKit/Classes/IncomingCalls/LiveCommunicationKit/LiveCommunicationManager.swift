#if EASE_CALL_LCK
import UIKit
import AVFAudio
import LiveCommunicationKit

@available(iOS 17.4, *)
final class LiveCommunicationManager: NSObject, SystemIncomingCallPresenter, ConversationManagerDelegate {
    let presentation = IncomingCallPresentation.liveCommunicationKit
    private(set) var activeCallID: String?
    private var uuid: UUID?
    private var manager: ConversationManager?
    private var pendingAnswer: JoinConversationAction?

    func report(_ call: CallInfo, callerName: String, isCurrent: Bool, completion: @escaping (Bool) -> Void) {
        let callID = call.callId
        let id = activeCallID == callID ? uuid ?? UUID() : UUID(uuidString: callID) ?? UUID()
        let alreadyReported = isCurrent && activeCallID == callID
        let manager = manager ?? makeManager()
        if isCurrent {
            self.manager = manager
            activeCallID = callID
            uuid = id
        }
        let handle = Handle(type: .generic, value: call.callerId.isEmpty ? "Unknown" : call.callerId,
                            displayName: callerName.isEmpty ? nil : callerName)
        let capabilities: Conversation.Capabilities = call.type == .singleAudio ? [] : [.video]
        let update = Conversation.Update(localMember: handle, members: [handle], activeRemoteMembers: [handle],
                                         capabilities: capabilities)
        Task { @MainActor in
            do {
                try await manager.reportNewIncomingConversation(uuid: id, update: update)
                if !isCurrent {
                    if let conversation = manager.conversations.first(where: { $0.uuid == id }) {
                        manager.reportConversationEvent(.conversationEnded(Date(), .failed), for: conversation)
                    }
                    if self.manager !== manager { manager.invalidate() }
                }
                completion(isCurrent && !alreadyReported)
            } catch {
                if isCurrent, !alreadyReported, self.uuid == id {
                    end(reason: .abnormalEnd)
                } else if self.manager !== manager {
                    manager.invalidate()
                }
                consoleLogInfo("Could not report LiveCommunicationKit call: \(error.localizedDescription)", type: .error)
                completion(false)
            }
        }
    }

    private func makeManager() -> ConversationManager {
        let config = CallKitManager.shared.config
        let manager = ConversationManager(configuration: .init(
            ringtoneName: nil, iconTemplateImageData: UIImage(named: "AppIcon")?.pngData(),
            maximumConversationGroups: config.maximumConversationGroups,
            maximumConversationsPerConversationGroup: config.maximumConversationsPerConversationGroup,
            includesConversationInRecents: false, supportsVideo: true, supportedHandleTypes: [.generic]
        ))
        manager.delegate = self
        return manager
    }

    func requestAnswer() {
        guard pendingAnswer == nil, let uuid else { return }
        perform(JoinConversationAction(conversationUUID: uuid))
    }

    func inviteConfirmed() {
        guard let action = pendingAnswer else { return }
        pendingAnswer = nil
        CallKitManager.shared.acceptIncomingCall()
        action.fulfill()
    }

    func setMuted(_ muted: Bool) {
        guard let uuid else { return }
        perform(MuteConversationAction(conversationUUID: uuid, isMuted: muted))
    }

    private func perform(_ action: ConversationAction) {
        guard let manager else { return }
        Task {
            do {
                try await manager.perform([action])
            } catch {
                consoleLogInfo("LiveCommunicationKit action failed: \(error.localizedDescription)", type: .error)
            }
        }
    }

    func end(reason: CallEndReason) {
        guard let manager else { return }
        pendingAnswer?.fail()
        pendingAnswer = nil
        self.manager = nil
        activeCallID = nil
        uuid = nil
        manager.invalidate()
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .background {
                ChatClient.shared().applicationDidEnterBackground(UIApplication.shared)
            }
        }
    }

    func conversationManager(_ manager: ConversationManager, perform action: ConversationAction) {
        guard manager === self.manager, action.conversationUUID == uuid else {
            action.fail()
            return
        }
        switch action {
        case let answer as JoinConversationAction:
            guard pendingAnswer == nil, let call = CallKitManager.shared.callInfo,
                  call.callId == activeCallID, call.state == .ringing else {
                action.fail()
                return
            }
            pendingAnswer = answer
            if CallKitManager.shared.confirmedIncomingCallID == call.callId {
                inviteConfirmed()
            }
        case is EndConversationAction:
            action.fulfill()
            hangupIfCurrent(manager)
        case let mute as MuteConversationAction:
            if CallKitManager.shared.callInfo?.state == .answering {
                CallKitManager.shared.applyLocalAudio(!mute.isMuted)
                action.fulfill()
            } else {
                action.fail()
            }
        default:
            action.fail()
        }
    }

    func conversationManager(_ manager: ConversationManager, conversationChanged conversation: Conversation) {}

    func conversationManagerDidBegin(_ manager: ConversationManager) {}

    func conversationManagerDidReset(_ manager: ConversationManager) {
        hangupIfCurrent(manager)
    }

    func conversationManager(_ manager: ConversationManager, timedOutPerforming action: ConversationAction) {
        guard action.conversationUUID == uuid else { return }
        if pendingAnswer === action { pendingAnswer = nil }
        hangupIfCurrent(manager)
    }

    func conversationManager(_ manager: ConversationManager, didActivate audioSession: AVAudioSession) {}

    func conversationManager(_ manager: ConversationManager, didDeactivate audioSession: AVAudioSession) {
        hangupIfCurrent(manager)
    }

    private func hangupIfCurrent(_ manager: ConversationManager) {
        guard manager === self.manager, let activeCallID,
              activeCallID == CallKitManager.shared.callInfo?.callId else { return }
        CallKitManager.shared.hangup()
    }
}
#endif
