// swift-tools-version:5.10
// Leftovers — a menu-bar app that finds memory leaked by other software
// and lets you reclaim it, while never touching macOS system processes.
import PackageDescription

let package = Package(
    name: "Leftovers",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Leftovers", path: "Sources/Leftovers")
    ]
)
