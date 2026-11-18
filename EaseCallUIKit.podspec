#
# Be sure to run `pod lib lint EaseCallUIKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'EaseCallUIKit'
  s.version          = '4.26.0'
  s.summary          = 'A short description of EaseCallUIKit.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/Easemob-Community/easemob-callkit-iOS'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'zjc19891106' => '984065974@qq.com' }
  s.source           = { :git => 'https://github.com/Easemob-Community/easemob-callkit-iOS.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '15.0'

  classes = 'Sources/EaseCallUIKit/Classes'
  s.static_framework = true
  s.swift_version = '5.0'
  s.default_subspecs = 'Core', 'APNs', 'LiveCommunicationKit'
  s.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' =>
      '$(inherited) $(EASE_CALL_LCK_CONDITION) $(EASE_CALL_APPLE_CALLKIT_CONDITION)'
  }

  s.subspec 'Core' do |core|
    core.source_files = "#{classes}/{Commons,CoreService,UI}/**/*.{h,m,swift}"
    core.resource_bundles = { 'EaseCallUIKit' => ["#{classes}/Resources/*.bundle"] }
    core.frameworks = 'UIKit', 'Foundation', 'Combine', 'AudioToolbox', 'AVFoundation',
                      'AVKit', 'CoreMedia', 'CoreVideo', 'CoreGraphics'
    core.dependency 'HyphenateChat', '4.26.0'
    core.dependency 'ShengwangRtcEngine_iOS/RtcBasic', '4.6.2'
  end

  s.subspec 'APNs' do |apns|
    apns.source_files = "#{classes}/IncomingCalls/APNs/**/*.swift"
    apns.frameworks = 'UserNotifications'
    apns.dependency 'EaseCallUIKit/Core'
  end

  s.subspec 'VoIP' do |voip|
    voip.source_files = "#{classes}/IncomingCalls/VoIP/**/*.swift"
    voip.frameworks = 'PushKit'
    voip.dependency 'EaseCallUIKit/Core'
  end

  s.subspec 'LiveCommunicationKit' do |live|
    live.source_files = "#{classes}/IncomingCalls/LiveCommunicationKit/**/*.swift"
    live.weak_frameworks = 'LiveCommunicationKit'
    live.pod_target_xcconfig = { 'EASE_CALL_LCK_CONDITION' => 'EASE_CALL_LCK' }
    live.dependency 'EaseCallUIKit/VoIP'
  end

  s.subspec 'AppleCallKit' do |apple|
    apple.source_files = "#{classes}/IncomingCalls/AppleCallKit/**/*.swift"
    apple.frameworks = 'CallKit'
    apple.pod_target_xcconfig = { 'EASE_CALL_APPLE_CALLKIT_CONDITION' => 'EASE_CALL_APPLE_CALLKIT' }
    apple.dependency 'EaseCallUIKit/VoIP'
  end

  # 默认为国内方式，iOS17.4及以上使用LiveCommunicationKit，以下版本使用普通Apns消息
  
  # 海外可使用此方式，iOS17.4及以上使用LiveCommunicationKit，以下版本使用AppleCallKit
  s.subspec 'Overseas' do |overseas|
    overseas.dependency 'EaseCallUIKit/APNs'
    overseas.dependency 'EaseCallUIKit/LiveCommunicationKit'
    overseas.dependency 'EaseCallUIKit/AppleCallKit'
  end

  # 海外可使用此方式，不区分系统版本统一使用AppleCallKit
  s.subspec 'OverseasCallKit' do |overseas|
    overseas.dependency 'EaseCallUIKit/APNs'
    overseas.dependency 'EaseCallUIKit/AppleCallKit'
  end

  s.test_spec 'Resources' do |test_spec|
    test_spec.dependency 'EaseCallUIKit/Core'
    test_spec.source_files = 'Tests/EaseCallUIKitTests/**/*.swift'
    test_spec.frameworks = 'XCTest', 'AVFoundation', 'UIKit'
  end
end
