import Foundation

/// A developer cache that rebuilds itself when needed. Emptying one costs a
/// slower next build or download, never your work.
enum CleanupTarget: String, CaseIterable, Identifiable, Codable {
    case xcodeDerivedData, xcodeDeviceSupport, simulatorCaches
    case swiftPM, npm, pnpm, yarn, bun, pip, uv, poetry
    case homebrew, cocoaPods, gradle, goBuild, cargo, playwright

    var id: String { rawValue }

    var title: String {
        switch self {
        case .xcodeDerivedData: return "Xcode build files"
        case .xcodeDeviceSupport: return "Xcode device support"
        case .simulatorCaches: return "Simulator caches"
        case .swiftPM: return "Swift packages"
        case .npm: return "npm"
        case .pnpm: return "pnpm"
        case .yarn: return "Yarn"
        case .bun: return "Bun"
        case .pip: return "pip"
        case .uv: return "uv"
        case .poetry: return "Poetry"
        case .homebrew: return "Homebrew downloads"
        case .cocoaPods: return "CocoaPods"
        case .gradle: return "Gradle"
        case .goBuild: return "Go build cache"
        case .cargo: return "Cargo downloads"
        case .playwright: return "Playwright browsers"
        }
    }

    /// Relative to the home folder.
    var relativePath: String {
        switch self {
        case .xcodeDerivedData: return "Library/Developer/Xcode/DerivedData"
        case .xcodeDeviceSupport: return "Library/Developer/Xcode/iOS DeviceSupport"
        case .simulatorCaches: return "Library/Developer/CoreSimulator/Caches"
        case .swiftPM: return "Library/Caches/org.swift.swiftpm"
        case .npm: return ".npm/_cacache"
        case .pnpm: return "Library/pnpm/store"
        case .yarn: return "Library/Caches/Yarn"
        case .bun: return ".bun/install/cache"
        case .pip: return "Library/Caches/pip"
        case .uv: return ".cache/uv"
        case .poetry: return "Library/Caches/pypoetry"
        case .homebrew: return "Library/Caches/Homebrew"
        case .cocoaPods: return "Library/Caches/CocoaPods"
        case .gradle: return ".gradle/caches"
        case .goBuild: return "Library/Caches/go-build"
        case .cargo: return ".cargo/registry/cache"
        case .playwright: return "Library/Caches/ms-playwright"
        }
    }

    func path(home: String = NSHomeDirectory()) -> String { home + "/" + relativePath }

    /// What you give up, in plain words.
    var cost: String {
        switch self {
        case .xcodeDerivedData: return "The next Xcode build starts from scratch."
        case .xcodeDeviceSupport: return "Rebuilt when you plug in a device again."
        case .playwright: return "Browsers download again on the next test run."
        case .homebrew: return "Old downloads; installed tools stay."
        default: return "Downloads again the next time it's needed."
        }
    }

    /// Process names that use it. Emptying waits until none are running.
    var usedBy: [String] {
        switch self {
        case .xcodeDerivedData, .swiftPM: return ["Xcode", "xcodebuild", "swift-build", "swift-frontend", "SourceKitService"]
        case .xcodeDeviceSupport: return ["Xcode"]
        case .simulatorCaches: return ["Simulator", "launchd_sim"]
        case .npm: return ["npm"]
        case .pnpm: return ["pnpm"]
        case .yarn: return ["yarn"]
        case .bun: return ["bun"]
        case .pip: return ["pip", "pip3"]
        case .uv: return ["uv"]
        case .poetry: return ["poetry"]
        case .homebrew: return ["brew"]
        case .cocoaPods: return ["pod"]
        case .gradle: return ["gradle"]
        case .goBuild: return ["go"]
        case .cargo: return ["cargo"]
        case .playwright: return ["playwright"]
        }
    }

    /// The first of `running` process names that uses this cache.
    func blocker(running: Set<String>) -> String? { usedBy.first(where: running.contains) }
}
