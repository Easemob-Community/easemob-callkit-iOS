//
//  CallKitConfig.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 8/8/25.
//

import Foundation

@objc public class CallKitConfig: NSObject {
    
    /// Indicates whether to enable Picture-in-Picture mode for 1v1 video calls
    public var enablePIPOn1V1VideoScene: Bool = false
    
    /// Request VoIP push for outgoing invitations and enable system incoming calls where supported.
    public var enableVOIP: Bool = false

    /// Allow Apple CallKit when its subspec or SwiftPM trait is included and LiveCommunicationKit is unavailable.
    public var enableAppleCallKit: Bool = true

    /// Notify the host when PushKit changes or invalidates the token. Called on the main queue.
    public var onVoIPTokenChange: ((Data?) -> Void)?
    
    /// Invitation and ringing timeout, in seconds. The default is 30.
    public var ringTimeOut = 30
    
    /// `LiveCommunicationKit` supports multiple conversation groups, and each conversation group supports multiple conversations.
    public var maximumConversationGroups: Int = 1
    
    /// `LiveCommunicationKit` supports multiple conversation groups, and each conversation group supports multiple conversations.
    public var maximumConversationsPerConversationGroup: Int = 1
    
    /// Disable RTC token validation
    public var disableRTCTokenValidation: Bool = false
}
