import Foundation
import XCTest
@testable import EaseCallUIKit

final class InvitePushPayloadTests: XCTestCase {
    func testInvitationMarksCallAndPreservesSignalingInPushPayload() throws {
        let signaling: [String: Any] = [
            kCallId: "incoming-call",
            kMsgType: kMsgTypeValue,
            kAction: CALL_INVITE,
            kChannelName: "channel",
            kCallKitGroupExt: ["groupId": "group"]
        ]
        let extensions = callInviteMessageExtensions(signaling, enableVOIP: true)

        XCTAssertEqual(extensions[kCallId] as? String, "incoming-call")
        XCTAssertNil(extensions[kPush_iOS_payload_apns])
        XCTAssertNil(extensions["em_ignore_notification"])

        let push = try XCTUnwrap(extensions[kPush_payload] as? [String: Any])
        XCTAssertEqual(push["type"] as? String, "call")
        let custom = try XCTUnwrap(push["custom"] as? [String: Any])
        XCTAssertEqual(custom[kCallId] as? String, "incoming-call")
        XCTAssertEqual(custom[kMsgType] as? String, kMsgTypeValue)
        XCTAssertEqual(custom[kAction] as? String, CALL_INVITE)
        XCTAssertEqual(custom[kChannelName] as? String, "channel")
        XCTAssertEqual(custom[kCallKitGroupExt] as? [String: String], ["groupId": "group"])
    }

    func testInvitationWithVoIPDisabledUsesOrdinaryAPNs() throws {
        let signaling = [kCallId: "incoming-call", kMsgType: kMsgTypeValue, kAction: CALL_INVITE]
        let extensions = callInviteMessageExtensions(signaling, enableVOIP: false)

        XCTAssertEqual(extensions[kCallId] as? String, "incoming-call")
        XCTAssertNil(extensions[kPush_payload])
        let apns = try XCTUnwrap(extensions[kPush_iOS_payload_apns] as? [String: String])
        let data = try XCTUnwrap(apns["extern"]?.data(using: .utf8))
        let notification = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(notification, signaling)
    }
}
