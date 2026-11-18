#if EASE_CALL_APPLE_CALLKIT
import UIKit
import AVFAudio
import CallKit
import AgoraRtcKit

final class AppleCallKitPresenter: NSObject, SystemIncomingCallPresenter, CXProviderDelegate {
    let presentation = IncomingCallPresentation.appleCallKit
    private(set) var activeCallID: String?
    private let provider: CXProvider
    private let controller = CXCallController()
    private var uuid: UUID?
    private var pendingAnswer: CXAnswerCallAction?
    private var answerStarted = false
    private var audioActive = false
    private var startMedia: (() -> Void)?

    override init() {
        let config = CXProviderConfiguration()
        config.supportsVideo = true
        config.supportedHandleTypes = [.generic]
        config.includesCallsInRecents = false
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: .main)
    }

    func report(_ call: CallInfo, callerName: String, isCurrent: Bool, completion: @escaping (Bool) -> Void) {
        let callID = call.callId
        let alreadyReported = isCurrent && activeCallID == callID
        let id = alreadyReported ? uuid ?? UUID() : UUID(uuidString: callID) ?? UUID()
        if isCurrent && !alreadyReported {
            activeCallID = callID
            uuid = id
        }
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: call.callerId.isEmpty ? "Unknown" : call.callerId)
        update.localizedCallerName = callerName.isEmpty ? nil : callerName
        update.hasVideo = call.type != .singleAudio
        provider.reportNewIncomingCall(with: id, update: update) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else {
                    completion(false)
                    return
                }
                if !isCurrent, error == nil {
                    self.provider.reportCall(with: id, endedAt: Date(), reason: .failed)
                } else if let error, !alreadyReported {
                    if isCurrent, self.uuid == id { self.clearCall() }
                    consoleLogInfo("Could not report Apple CallKit call: \(error.localizedDescription)", type: .error)
                }
                completion(isCurrent && !alreadyReported && error == nil)
            }
        }
    }

    func requestAnswer() {
        guard pendingAnswer == nil, !answerStarted, let uuid else { return }
        request(CXAnswerCallAction(call: uuid))
    }

    func inviteConfirmed() {
        guard pendingAnswer != nil, !answerStarted else { return }
        answerStarted = true
        CallKitManager.shared.acceptIncomingCall()
    }

    func setMuted(_ muted: Bool) {
        guard let uuid, audioActive else { return }
        request(CXSetMutedCallAction(call: uuid, muted: muted))
    }

    private func request(_ action: CXAction) {
        controller.request(CXTransaction(action: action)) { error in
            if let error {
                consoleLogInfo("Apple CallKit action failed: \(error.localizedDescription)", type: .error)
            }
        }
    }

    func connectMedia(whenReady: @escaping () -> Void) {
        guard let action = pendingAnswer, let engine = CallKitManager.shared.engine else {
            CallKitManager.shared.updateCallEndReason(.abnormalEnd)
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat)
        } catch {
            consoleLogInfo("Could not configure call audio: \(error.localizedDescription)", type: .error)
            CallKitManager.shared.updateCallEndReason(.abnormalEnd)
            return
        }
        engine.setAudioSessionOperationRestriction(.all)
        startMedia = whenReady
        pendingAnswer = nil
        action.fulfill()
        startMediaIfReady()
    }

    func end(reason: CallEndReason) {
        guard let uuid else { return }
        let systemReason: CXCallEndedReason
        switch reason {
        case .remoteCancel, .hangup, .cancel: systemReason = .remoteEnded
        case .handleOnOtherDevice: systemReason = .answeredElsewhere
        case .noResponse, .remoteNoResponse: systemReason = .unanswered
        case .refuse, .remoteRefuse: systemReason = .declinedElsewhere
        default: systemReason = .failed
        }
        clearCall()
        provider.reportCall(with: uuid, endedAt: Date(), reason: systemReason)
    }

    func providerDidReset(_ provider: CXProvider) {
        let isCurrent = activeCallID != nil && activeCallID == CallKitManager.shared.callInfo?.callId
        clearCall()
        if isCurrent { CallKitManager.shared.updateCallEndReason(.abnormalEnd) }
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard action.callUUID == uuid, let call = CallKitManager.shared.callInfo, call.callId == activeCallID,
              call.state == .ringing, pendingAnswer == nil, !answerStarted else {
            action.fail()
            return
        }
        pendingAnswer = action
        if CallKitManager.shared.confirmedIncomingCallID == call.callId { inviteConfirmed() }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        guard action.callUUID == uuid else {
            action.fail()
            return
        }
        clearCall()
        action.fulfill()
        CallKitManager.shared.hangup()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        guard action.callUUID == uuid else {
            action.fail()
            return
        }
        CallKitManager.shared.applyLocalAudio(!action.isMuted)
        action.fulfill()
    }

    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        guard let action = action as? CXCallAction, action.callUUID == uuid else { return }
        if pendingAnswer === action { pendingAnswer = nil }
        CallKitManager.shared.updateCallEndReason(.noResponse)
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        guard uuid != nil else { return }
        audioActive = true
        CallKitManager.shared.engine?.enableAudio()
        startMediaIfReady()
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        guard audioActive else { return }
        audioActive = false
        CallKitManager.shared.engine?.disableAudio()
    }

    private func startMediaIfReady() {
        guard audioActive, let startMedia else { return }
        self.startMedia = nil
        startMedia()
    }

    private func clearCall() {
        pendingAnswer?.fail()
        pendingAnswer = nil
        activeCallID = nil
        uuid = nil
        answerStarted = false
        audioActive = false
        startMedia = nil
        CallKitManager.shared.engine?.setAudioSessionOperationRestriction([])
    }
}
#endif
