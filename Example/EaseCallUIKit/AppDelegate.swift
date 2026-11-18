//
//  AppDelegate.swift
//  EaseCallUIKit
//
//  Created by zjc19891106 on 06/24/2025.
//  Copyright (c) 2025 zjc19891106. All rights reserved.
//

import UIKit
import UserNotifications
import EaseCallUIKit
#if targetEnvironment(simulator)
import ObjectiveC.runtime
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, ChatClientListener {

    static let sessionDidChange = Notification.Name("EaseCallExampleSessionDidChange")

    var window: UIWindow?
    private static let lastAppKey = "EaseCallExample.LastAppKey"

    private(set) var isLoggingIn = false
    private(set) var isLoggingOut = false
    private(set) var loginError: String?
    private(set) var activeAppKey: String?
    private var signedInAccount: String?

    var isLoggedIn: Bool {
        activeAppKey != nil && ChatClient.shared().isLoggedIn
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if targetEnvironment(simulator)
        _ = Self.installSimulatorPushTokenSwizzle
        #endif
        UNUserNotificationCenter.current().delegate = self
        let savedAppKey = UserDefaults.standard.string(forKey: Self.lastAppKey)
        let appKey = savedAppKey ?? AppKey
        if !appKey.isEmpty {
            isLoggingIn = savedAppKey != nil
            if !initializeIM(appKey: appKey) { isLoggingIn = false }
            updateSession()
        }
        return true
    }

    private func initializeIM(appKey: String) -> Bool {
        let options = ChatSDKOptions(appkey: appKey)
        options.enableConsoleLog = true
        options.isAutoLogin = true

        // 设置推送证书
        #if DEBUG
            options.apnsCertName = "iim_apns_dev"
            options.pushKitCertName = "iim_voip_dev"  // VoIP 证书
        #else
            options.apnsCertName = "iim_apns_release"
            options.pushKitCertName = "iim_voip_release"  // VoIP 证书
        #endif

        let client = ChatClient.shared()
        if let error = client.initializeSDK(with: options) {
            loginError = error.errorDescription ?? "Could not initialize IM"
            return false
        }
        activeAppKey = appKey
        client.add(self, delegateQueue: .main)

        let config = CallKitConfig()
        config.enablePIPOn1V1VideoScene = true
        config.enableVOIP = options.pushKitCertName?.isEmpty == false
        CallKitManager.shared.setup(config)

        if options.apnsCertName?.isEmpty == false {
            CallNotificationHandler.shared.registerForNotifications()
        }
        return true
    }

    func login(appKey: String, username: String, token: String) {
        guard !appKey.isEmpty, !username.isEmpty, !token.isEmpty, !isLoggingIn, !isLoggingOut,
              !isLoggedIn else { return }
        isLoggingIn = true
        loginError = nil
        if let activeAppKey, activeAppKey != appKey {
            if let error = ChatClient.shared().changeAppkey(appKey) {
                finishLogin(error)
                return
            }
            self.activeAppKey = appKey
            let manager = CallKitManager.shared
            let config = manager.config
            manager.tearDown()
            manager.appID = ""
            manager.cleanUserDefaults()
            manager.setup(config)
        } else if activeAppKey == nil, !initializeIM(appKey: appKey) {
            isLoggingIn = false
            updateSession()
            return
        }
        updateSession()
        ChatClient.shared().login(withUsername: username, token: token) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.finishLogin(error)
            }
        }
    }

    func logout() {
        guard isLoggedIn, !isLoggingIn, !isLoggingOut else { return }
        isLoggingOut = true
        loginError = nil
        CallKitManager.shared.hangup()
        updateSession()
        ChatClient.shared().logout(true) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoggingOut = false
                if let error {
                    self.loginError = error.errorDescription ?? "Logout failed"
                } else {
                    self.clearSession()
                }
                self.updateSession()
            }
        }
    }

    func autoLoginDidCompleteWithError(_ error: ChatError?) {
        finishLogin(error)
    }

    func connectionStateDidChange(_ state: ConnectionState) {
        updateSession()
    }

    func userAccountDidForced(toLogout error: ChatError?) {
        clearSession()
        finishLogin(error)
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: Self.lastAppKey)
        signedInAccount = nil
        let manager = CallKitManager.shared
        manager.currentUserInfo = nil
        manager.usersCache.removeAll()
        manager.cleanUserDefaults()
    }

    private func finishLogin(_ error: ChatError?) {
        isLoggingIn = false
        loginError = error.map { $0.errorDescription ?? "Login failed" }
        if error == nil, let activeAppKey, isLoggedIn {
            UserDefaults.standard.set(activeAppKey, forKey: Self.lastAppKey)
        }
        updateSession()
    }

    private func updateSession() {
        let client = ChatClient.shared()
        if !isLoggingOut, client.isLoggedIn, client.connectionState == .connected,
           let account = client.currentUsername, !account.isEmpty {
            if isLoggingIn {
                isLoggingIn = false
                loginError = nil
                if let activeAppKey { UserDefaults.standard.set(activeAppKey, forKey: Self.lastAppKey) }
            }
            if signedInAccount != account {
                signedInAccount = account
                let profile = CallUserProfile()
                profile.id = account
                profile.nickname = account
                CallKitManager.shared.currentUserInfo = profile
                CallNotificationHandler.shared.bindDeviceToken()
            }
        }
        NotificationCenter.default.post(name: Self.sessionDidChange, object: self)
    }

    func notifyIMDidEnterBackground() {
        if activeAppKey != nil { ChatClient.shared().applicationDidEnterBackground(UIApplication.shared) }
    }

    func notifyIMWillEnterForeground() {
        if activeAppKey != nil { ChatClient.shared().applicationWillEnterForeground(UIApplication.shared) }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        CallNotificationHandler.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        CallNotificationHandler.shared.handle(response)
        completionHandler()
    }
}

#if targetEnvironment(simulator)
private extension AppDelegate {
    static let installSimulatorPushTokenSwizzle: Void = {
        let selector = NSSelectorFromString("_extractTokenFromRawData:")
        // HyphenateChat 5.2.0 uses an Objective-C object return and one object argument.
        guard let method = class_getInstanceMethod(ChatClient.self, selector),
              let encoding = method_getTypeEncoding(method),
              String(cString: encoding) == "@24@0:8@16" else {
            NSLog("HyphenateChat simulator token swizzle unavailable for this SDK version.")
            return
        }

        let extractToken: @convention(block) (ChatClient, AnyObject?) -> NSString = { _, rawToken in
            if let data = rawToken as? Data {
                return data.map { String(format: "%02x", UInt32($0)) }.joined() as NSString
            }
            if let token = rawToken as? String {
                return token.replacingOccurrences(of: "<", with: "")
                    .replacingOccurrences(of: ">", with: "")
                    .replacingOccurrences(of: " ", with: "") as NSString
            }
            return ""
        }
        method_setImplementation(method, imp_implementationWithBlock(extractToken))
    }()
}
#endif
