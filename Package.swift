// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iPhoneRingtones",
    // build.sh 의 MIN_MACOS 와 같게 유지 (AVAssetExportSession.export(to:as:) 가 macOS 15+)
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "iPhoneRingtones"),
        .testTarget(name: "iPhoneRingtonesTests", dependencies: ["iPhoneRingtones"]),
    ]
)
