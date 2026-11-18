//
//  ViewController.swift
//  EaseCallUIKit
//
//  Created by zjc19891106 on 06/24/2025.
//  Copyright (c) 2025 zjc19891106. All rights reserved.
//

import UIKit
import EaseCallUIKit
import QuickLook
import AgoraRtcKit

class ViewController: UIViewController, UITextFieldDelegate {

    private static let accent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.55, blue: 0.45, alpha: 1)
            : UIColor(red: 0.03, green: 0.30, blue: 0.25, alpha: 1)
    }
    private static let pageColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemBackground
            : UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1)
    }
    private static let cardColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .secondarySystemBackground : .white
    }

    private let formScrollView = UIScrollView()
    private let inputField = UITextField()
    private let appKeyField = UITextField()
    private let userIDField = UITextField()
    private let tokenField = UITextField()
    private let callButton = UIButton(type: .system)
    private let loginButton = UIButton(type: .system)
    private let logoutButton = UIButton(type: .system)
    private let accountDetailsButton = UIButton(type: .system)
    private let callTypeSegment = UISegmentedControl(items: ["Audio", "Video", "Group"])
    private let sessionLabel = UILabel()
    private let accountErrorLabel = UILabel()
    private let accountLabel = UILabel()
    private var accountRow: UIStackView?
    private let pushLabel = UILabel()
    private let targetLabel = UILabel()
    private let currentCallLabel = UILabel()
    private let lastCallLabel = UILabel()
    private let accountFields = UIStackView()

    private var lastCallResult: String?
    private var showsAccountDetails = false

    private var appDelegate: AppDelegate? {
        UIApplication.shared.delegate as? AppDelegate
    }

    private var callType: CallType {
        switch callTypeSegment.selectedSegmentIndex {
        case 1: return .singleVideo
        case 2: return .groupCall
        default: return .singleAudio
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildDashboard()
        appKeyField.text = AppKey
        userIDField.text = userId
        tokenField.text = token
        updateTargetField()
        CallKitManager.shared.profileProvider = self
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateSession), name: AppDelegate.sessionDidChange, object: appDelegate
        )
        updateSession()
        updateCallStatus()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateSession()
        updateCallStatus()
    }

    @objc private func updateSession() {
        guard let appDelegate else { return }
        let client = ChatClient.shared()
        let isLoggedIn = appDelegate.isLoggedIn
        let isReady = isLoggedIn && client.connectionState == .connected
        let isBusy = appDelegate.isLoggingIn || appDelegate.isLoggingOut
        for field in [appKeyField, userIDField, tokenField] {
            field.isEnabled = !isLoggedIn && !isBusy
        }
        inputField.isEnabled = isReady && !isBusy
        callTypeSegment.isEnabled = isReady && !isBusy
        updateCallButton()
        loginButton.isHidden = isLoggedIn
        loginButton.isEnabled = !isBusy
        logoutButton.isHidden = !isLoggedIn
        logoutButton.isEnabled = !isBusy
        accountRow?.isHidden = !isLoggedIn
        accountLabel.text = client.currentUsername
        accountDetailsButton.isHidden = !isLoggedIn
        if !isLoggedIn { showsAccountDetails = false }
        updateAccountDetails()

        if isLoggedIn {
            appKeyField.text = appDelegate.activeAppKey
            userIDField.text = client.currentUsername
            if let activeToken = client.accessUserToken, !activeToken.isEmpty {
                tokenField.text = activeToken
            }
        }

        let status: String
        if appDelegate.isLoggingOut {
            status = "Signing out…"
        } else if isReady {
            status = "Connected"
        } else if isBusy || isLoggedIn {
            status = "Connecting to IM…"
        } else {
            status = "Signed out"
        }

        CallKitManager.shared.addListener(self)
        updateCallStatus()
        let incoming: String
        switch CallKitManager.shared.incomingCallPresentation {
        case .appleCallKit: incoming = "Apple CallKit"
        case .liveCommunicationKit: incoming = "LiveCommunicationKit"
        case .inApp: incoming = "In-app"
        @unknown default: incoming = "In-app"
        }
        let outgoing = CallKitManager.shared.config.enableVOIP ? "VoIP preferred" : "APNs"
        sessionLabel.text = status
        sessionLabel.textColor = isReady ? Self.accent : .secondaryLabel
        accountErrorLabel.text = appDelegate.loginError
        accountErrorLabel.isHidden = appDelegate.loginError == nil
        pushLabel.text = "Incoming: \(incoming) · Outgoing: \(outgoing)"
        pushLabel.isHidden = !isLoggedIn
    }

    private func buildDashboard() {
        view.backgroundColor = Self.pageColor
        view.tintColor = Self.accent
        formScrollView.keyboardDismissMode = .onDrag
        formScrollView.alwaysBounceVertical = true
        formScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(formScrollView)

        let dashboard = stack([], spacing: 12)
        dashboard.translatesAutoresizingMaskIntoConstraints = false
        formScrollView.addSubview(dashboard)
        let frame = formScrollView.frameLayoutGuide
        let content = formScrollView.contentLayoutGuide
        let horizontalMargin: CGFloat = 20
        let preferredWidth = dashboard.widthAnchor.constraint(equalTo: frame.widthAnchor, constant: -2 * horizontalMargin)
        preferredWidth.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            formScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            formScrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            formScrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            formScrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            dashboard.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            dashboard.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            content.widthAnchor.constraint(equalTo: frame.widthAnchor),
            dashboard.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            dashboard.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: horizontalMargin),
            dashboard.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -horizontalMargin),
            dashboard.widthAnchor.constraint(lessThanOrEqualToConstant: 540),
            preferredWidth
        ])

        let icon = UIImageView(image: UIImage(systemName: "phone.fill",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)))
        icon.tintColor = .white
        icon.contentMode = .center
        icon.backgroundColor = Self.accent
        icon.layer.cornerRadius = 12
        icon.widthAnchor.constraint(equalToConstant: 42).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 42).isActive = true
        let title = label("EaseCall", style: .largeTitle)
        title.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: .systemFont(ofSize: 31, weight: .bold))
        title.accessibilityTraits.insert(.header)
        let logs = UIButton(type: .system)
        configureButton(logs, title: "Logs", symbol: "doc.text", action: #selector(logAction))
        dashboard.addArrangedSubview(row([icon, title, UIView(), logs], spacing: 10))

        let accountTitle = heading("Account")
        configureLabel(sessionLabel, style: .footnote, color: .secondaryLabel)
        sessionLabel.textAlignment = .right
        sessionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        accountTitle.setContentCompressionResistancePriority(.required, for: .horizontal)
        configureLabel(accountLabel, style: .body)
        configureLabel(accountErrorLabel, style: .footnote, color: .systemRed)
        configureLabel(pushLabel, style: .footnote, color: .secondaryLabel)
        configureButton(loginButton, title: "Log in", symbol: "person.badge.key",
                        action: #selector(loginAction), filled: true)
        configureButton(logoutButton, title: "Log out", symbol: "rectangle.portrait.and.arrow.right",
                        action: #selector(logoutAction))
        logoutButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        let accountRow = row([accountLabel, UIView(), logoutButton])
        accountRow.isHidden = true
        self.accountRow = accountRow
        configureButton(accountDetailsButton, title: "Account details", symbol: "chevron.down",
                        action: #selector(toggleAccountDetails))
        accountDetailsButton.configuration?.imagePlacement = .trailing
        accountDetailsButton.contentHorizontalAlignment = .leading

        accountFields.axis = .vertical
        accountFields.spacing = 8
        for (field, title) in [(appKeyField, "App Key"), (userIDField, "User ID"), (tokenField, "Token")] {
            configureField(field)
            field.placeholder = title
            field.accessibilityLabel = title
            field.returnKeyType = field === tokenField ? .go : .next
            accountFields.addArrangedSubview(stack([label(title, style: .footnote), field], spacing: 3))
        }
        tokenField.isSecureTextEntry = true

        let accountCard = card([
            row([accountTitle, UIView(), sessionLabel]), accountRow, accountDetailsButton,
            accountFields, accountErrorLabel, loginButton, pushLabel
        ])
        dashboard.addArrangedSubview(accountCard)

        callTypeSegment.selectedSegmentIndex = 0
        callTypeSegment.selectedSegmentTintColor = Self.accent
        callTypeSegment.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        callTypeSegment.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        callTypeSegment.addTarget(self, action: #selector(chooseCallType), for: .valueChanged)
        configureLabel(targetLabel, style: .footnote)
        configureField(inputField)
        inputField.addTarget(self, action: #selector(updateCallButton), for: .editingChanged)
        configureButton(callButton, title: "Start audio call", symbol: "phone.fill",
                        action: #selector(startCall), filled: true)
        dashboard.addArrangedSubview(card([
            heading("New call"), callTypeSegment, stack([targetLabel, inputField], spacing: 5), callButton
        ]))

        dashboard.addArrangedSubview(card([
            heading("Call status"),
            statusRow("Current", icon: "waveform", value: currentCallLabel),
            statusRow("Last call", icon: "clock", value: lastCallLabel)
        ]))
    }

    private func stack(_ views: [UIView], spacing: CGFloat) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = spacing
        return stack
    }

    private func row(_ views: [UIView], spacing: CGFloat = 8) -> UIStackView {
        let row = UIStackView(arrangedSubviews: views)
        row.alignment = .center
        row.spacing = spacing
        return row
    }

    private func card(_ views: [UIView]) -> UIStackView {
        let card = stack(views, spacing: 8)
        card.isLayoutMarginsRelativeArrangement = true
        card.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        card.backgroundColor = Self.cardColor
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        return card
    }

    private func configureLabel(_ label: UILabel, style: UIFont.TextStyle, color: UIColor = .label) {
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = color
    }

    private func label(_ text: String, style: UIFont.TextStyle) -> UILabel {
        let label = UILabel()
        configureLabel(label, style: style)
        label.text = text
        return label
    }

    private func heading(_ text: String) -> UILabel {
        let label = label(text, style: .title3)
        label.font = UIFontMetrics(forTextStyle: .title3).scaledFont(for: .systemFont(ofSize: 20, weight: .bold))
        label.accessibilityTraits.insert(.header)
        return label
    }

    private func configureButton(_ button: UIButton, title: String, symbol: String,
                                 action: Selector, filled: Bool = false) {
        var configuration = filled ? UIButton.Configuration.filled() : .tinted()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 7
        configuration.cornerStyle = .large
        configuration.baseBackgroundColor = Self.accent
        if filled {
            configuration.baseForegroundColor = .white
        }
        button.configuration = configuration
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: filled ? 48 : 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func configureField(_ field: UITextField) {
        field.delegate = self
        field.borderStyle = .roundedRect
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.backgroundColor = Self.pageColor
        field.layer.cornerRadius = 8
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.clearButtonMode = .whileEditing
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }

    private func statusRow(_ title: String, icon: String, value: UILabel) -> UIStackView {
        let symbol = UIImageView(image: UIImage(systemName: icon))
        symbol.tintColor = Self.accent
        symbol.widthAnchor.constraint(equalToConstant: 20).isActive = true
        symbol.contentMode = .scaleAspectFit
        let name = label(title, style: .subheadline)
        name.setContentCompressionResistancePriority(.required, for: .horizontal)
        configureLabel(value, style: .subheadline, color: .secondaryLabel)
        value.textAlignment = .right
        return row([symbol, name, value], spacing: 10)
    }

    private func updateTargetField() {
        let target = callType == .groupCall ? "Target Group ID" : "Target User ID"
        targetLabel.text = target
        inputField.placeholder = callType == .groupCall ? "Enter a group ID" : "Enter a user ID"
        inputField.accessibilityLabel = target
        inputField.returnKeyType = callType == .groupCall ? .next : .go
        inputField.reloadInputViews()
        updateCallButton()
    }

    private func updateCallStatus() {
        guard isViewLoaded else { return }
        let manager = CallKitManager.shared
        let call = manager.callInfo ?? manager.receivedCalls.values.first
        let current: String
        switch call?.state {
        case .dialing: current = "Calling…"
        case .ringing: current = "Incoming call"
        case .answering: current = "In call"
        default: current = "Idle"
        }
        currentCallLabel.text = current
        lastCallLabel.text = lastCallResult ?? "No completed calls"
        updateCallButton()
    }

    @objc private func chooseCallType() {
        updateTargetField()
    }

    @objc private func loginAction() {
        let key = appKeyField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let username = userIDField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let token = tokenField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty, !username.isEmpty, !token.isEmpty else {
            accountErrorLabel.text = "Enter your App Key, user ID and token."
            accountErrorLabel.isHidden = false
            if key.isEmpty { appKeyField.becomeFirstResponder() }
            else if username.isEmpty { userIDField.becomeFirstResponder() }
            else { tokenField.becomeFirstResponder() }
            return
        }
        view.endEditing(true)
        appDelegate?.login(appKey: key, username: username, token: token)
    }

    @objc private func logoutAction() {
        view.endEditing(true)
        appDelegate?.logout()
    }

    @objc private func logAction() {
        let previewController = QLPreviewController()
        previewController.dataSource = self
        present(previewController, animated: true)
    }

    @objc private func toggleAccountDetails() {
        showsAccountDetails.toggle()
        updateAccountDetails()
    }

    private func updateAccountDetails() {
        accountFields.isHidden = appDelegate?.isLoggedIn == true && !showsAccountDetails
        accountDetailsButton.configuration?.image = UIImage(
            systemName: showsAccountDetails ? "chevron.up" : "chevron.down"
        )
        accountDetailsButton.accessibilityValue = showsAccountDetails ? "Expanded" : "Collapsed"
    }

    @objc private func updateCallButton() {
        let title: String
        let symbol: String
        switch callType {
        case .singleAudio: (title, symbol) = ("Start audio call", "phone.fill")
        case .singleVideo: (title, symbol) = ("Start video call", "video.fill")
        case .groupCall: (title, symbol) = ("Choose participants", "person.2.fill")
        @unknown default: (title, symbol) = ("Start call", "phone.fill")
        }
        callButton.configuration?.title = title
        callButton.configuration?.image = UIImage(systemName: symbol)
        let manager = CallKitManager.shared
        let hasCall = manager.callInfo.map { $0.state != .idle } ?? false
        callButton.isEnabled = inputField.isEnabled && !hasCall &&
            inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
            let frame = textField.convert(textField.bounds, to: self.formScrollView)
            self.formScrollView.scrollRectToVisible(frame.insetBy(dx: 0, dy: -12), animated: false)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === inputField {
            startCall()
        } else if textField === appKeyField {
            userIDField.becomeFirstResponder()
        } else if textField === userIDField {
            tokenField.becomeFirstResponder()
        } else {
            loginAction()
        }
        return true
    }

    @objc private func startCall() {
        guard callButton.isEnabled else { return }
        guard let target = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !target.isEmpty else {
            showCallToast(toast: callType == .groupCall ? "Enter a group ID." : "Enter a user ID.")
            return
        }
        view.endEditing(true)

        if callType == .groupCall {
            CallKitManager.shared.groupCall(groupId: target)
        } else {
            CallKitManager.shared.call(with: target, type: callType)
        }
        updateCallStatus()
    }
}

extension ViewController: QLPreviewControllerDataSource {
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }
    
    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/HyphenateSDK/easemobLog/easemob.log")
        return fileURL as QLPreviewItem
    }
    
    
}

extension ViewController: CallUserProfileProvider {
    func fetchUserProfiles(profileIds: [String]) async -> [any CallProfileProtocol] {
        return await withTaskGroup(of: [EaseCallUIKit.CallProfileProtocol].self, returning: [EaseCallUIKit.CallProfileProtocol].self) { group in
            var resultProfiles: [EaseCallUIKit.CallProfileProtocol] = []
            group.addTask {
                var resultProfiles: [EaseCallUIKit.CallProfileProtocol] = []
                let result = await self.requestUserInfos(profileIds: profileIds)
                if let infos = result {
                    resultProfiles.append(contentsOf: infos)
                }
                return resultProfiles
            }
            //Await all task were executed.Return values.
            for await result in group {
                resultProfiles.append(contentsOf: result)
            }
            return resultProfiles
        }
    }
    
    func fetchGroupProfiles(profileIds: [String]) async -> [any CallProfileProtocol] {
        return await withTaskGroup(of: [EaseCallUIKit.CallProfileProtocol].self, returning: [EaseCallUIKit.CallProfileProtocol].self) { group in
            var resultProfiles: [EaseCallUIKit.CallProfileProtocol] = []
            group.addTask {
                var resultProfiles: [EaseCallUIKit.CallProfileProtocol] = []
                let result = await self.requestGroupsInfo(groupIds: profileIds)
                if let infos = result {
                    resultProfiles.append(contentsOf: infos)
                }
                return resultProfiles
            }
            //Await all task were executed.Return values.
            for await result in group {
                resultProfiles.append(contentsOf: result)
            }
            return resultProfiles
        }
    }
    
    private func requestUserInfos(profileIds: [String]) async -> [CallProfileProtocol]? {
        var unknownIds = [String]()
        var resultProfiles = [CallProfileProtocol]()
        for profileId in profileIds {
            if let profile = CallKitManager.shared.usersCache[profileId] {
                resultProfiles.append(profile)
            } else {
                unknownIds.append(profileId)
            }
        }
        if unknownIds.isEmpty {
            return resultProfiles
        }
        let result = await ChatClient.shared().userInfoManager?.fetchUserInfo(byId: unknownIds)
        if result?.1 == nil,let infoMap = result?.0 {
            for (userId,info) in infoMap {
                let profile = CallUserProfile()
                let nickname = info.nickname ?? ""
                profile.id = userId
                profile.nickname = nickname
                profile.avatarURL = info.avatarUrl ?? ""
                resultProfiles.append(profile)
            }
            return resultProfiles
        }
        return []
    }
    
    private func requestGroupsInfo(groupIds: [String]) async -> [CallProfileProtocol]? {
        var resultProfiles = [CallProfileProtocol]()
        let groups = ChatClient.shared().groupManager?.getJoinedGroups() ?? []
        for groupId in groupIds {
            if let group = groups.first(where: { $0.groupId == groupId }) {
                let profile = CallUserProfile()
                profile.id = groupId
                profile.nickname = group.groupName
                profile.avatarURL = group.settings.ext
                resultProfiles.append(profile)
            }

        }
        return resultProfiles
    }

    
}

extension ViewController: CallServiceListener {
    func didOccurError(error: CallError) {
        DispatchQueue.main.async {
            self.showCallToast(toast: "Occur error:\(error.errorMessage) on module:\(error.module.rawValue)")
        }
        switch error {
        case .im(.invalidURL):
            print("Invalid URL")
        case .rtc(.invalidToken):
            print("Invalid Token")
        case .business(.state):
            print("State error")
        case .business(.param):
            print("Param error")
        default:
            // 注意这里要通过 error.error.message 访问
            print("Other error: \(error.error.message)")
        }
//        switch error.module {//OC use case
//        case .im:
//            switch error.getIMError() {
//            case .invalidURL:
//                print("")
//            default:
//                break
//            }
//        case .rtc:
//            switch error.getRTCError() {
//            case .invalidToken:
//                print("")
//            default:
//                break
//            }
//        case .business:
//            switch error.getCallBusinessError() {
//            case .state:
//                print("")
//            case .param:
//                print("")
//            case .signaling:
//                print("")
//            default:
//                break
//            }
//        default:
//            break
//        }
    }
        
    func didUpdateCallEndReason(reason: CallEndReason, info: CallInfo) {
        let result: String
        switch reason {
        case .hangup: result = "Call ended"
        case .cancel: result = "You canceled"
        case .remoteCancel: result = "Caller canceled"
        case .refuse: result = "You declined"
        case .remoteRefuse: result = "Declined by the other party"
        case .busy: result = "The other party was busy"
        case .noResponse: result = "Timed out"
        case .remoteNoResponse: result = "The other party did not answer"
        case .handleOnOtherDevice: result = "Handled on another device"
        case .abnormalEnd: result = "Call ended unexpectedly"
        @unknown default: result = "Call ended"
        }

        lastCallResult = result
        updateCallStatus()
        NotificationCenter.default.post(name: Notification.Name("didUpdateCallEndReason"), object: info.inviteMessageId)
    }

    func onReceivedCall(callType: CallType, userId: String, extensionInfo: [String: Any]?) {
        DispatchQueue.main.async { [weak self] in self?.updateCallStatus() }
    }

    func remoteUserDidJoined(userId: String, channelName: String, type: CallType) {
        DispatchQueue.main.async { [weak self] in self?.updateCallStatus() }
    }
    
    func onRtcEngineCreated(engine: AgoraRtcEngineKit) {
        
    }
}
