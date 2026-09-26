// swift-tools-version:5.10
// Memory Janitor — a menu-bar app that finds memory leaked by other software
// and lets you reclaim it, while never touching macOS system processes.
import PackageDescription

let package = Package(
    name: "MemoryJanitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "MemoryJanitor", path: "Sources/MemoryJanitor")
    ]
)
