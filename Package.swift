// swift-tools-version:5.10
// Leftovers: a menu-bar app that finds memory leaked by other software and
// lets you reclaim it, while never touching macOS system processes.
import PackageDescription

let package = Package(
    name: "Leftovers",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Updates for the notarized direct download (App Store is not possible:
        // the sandbox hides other processes).
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Leftovers",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Leftovers",
            // Sparkle.framework is embedded in Contents/Frameworks by scripts/bundle.sh.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "LeftoversTests", dependencies: ["Leftovers"], path: "Tests/LeftoversTests"),
    ]
)
