// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PrayerKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PrayerKit", targets: ["PrayerKit"]),
    ],
    targets: [
        // Compiles PrayerTimeCalculator + Prayer (symlinked from the iOS app)
        // as a standalone library so the test target can exercise them on macOS.
        .target(
            name: "PrayerKit",
            path: "Sources/PrayerKit"
        ),
        .testTarget(
            name: "PrayerKitTests",
            dependencies: ["PrayerKit"],
            path: "Tests/PrayerKitTests"
        ),
    ]
)
