// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ARCaptcha",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "ARCaptcha", targets: ["ARCaptcha"]),
    ],
    targets: [
        .target(
            name: "ARCaptcha",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "ARCaptchaTests",
            dependencies: ["ARCaptcha"]
        ),
    ]
)
