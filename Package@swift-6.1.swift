// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "EaseCallUIKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "EaseCallUIKit", targets: ["EaseCallUIKit"])
    ],
    traits: [
        .trait(name: "LiveCommunicationKit", description: "Use LiveCommunicationKit on iOS 17.4 and later."),
        .trait(name: "AppleCallKit", description: "Use Apple CallKit when LiveCommunicationKit is unavailable or excluded."),
        .default(enabledTraits: ["LiveCommunicationKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/easemob/HyphenateChat_iOS.git", exact: "4.26.0"),
        .package(url: "https://github.com/Shengwang-Lab/ShengwangRtcEngine_iOS.git", exact: "4.6.2")
    ],
    targets: [
        .target(
            name: "EaseCallUIKit",
            dependencies: [
                .product(name: "HyphenateChat", package: "HyphenateChat_iOS"),
                .product(name: "RtcBasic", package: "ShengwangRtcEngine_iOS")
            ],
            path: "Sources/EaseCallUIKit/Classes",
            resources: [.copy("Resources/CallResource.bundle")],
            swiftSettings: [
                .define("EASE_CALL_LCK", .when(traits: ["LiveCommunicationKit"])),
                .define("EASE_CALL_APPLE_CALLKIT", .when(traits: ["AppleCallKit"]))
            ]
        ),
        .testTarget(
            name: "EaseCallUIKitTests",
            dependencies: ["EaseCallUIKit"],
            path: "Tests/EaseCallUIKitTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
