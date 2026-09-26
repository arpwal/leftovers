import Foundation

/// Coding agents whose process trees are worth attributing memory to.
enum AgentKind: String, CaseIterable, Codable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case geminiCLI = "Gemini CLI"
    case cursorAgent = "Cursor Agent"
    case aider = "Aider"
    case openCode = "OpenCode"

    /// Recognises an agent from its executable path and arguments.
    /// Claude Code runs as a versioned binary (`…/claude/versions/2.1.283`),
    /// so its process name is a version number — the path is the reliable signal.
    static func detect(path: String, name: String, arguments: [String]) -> AgentKind? {
        if path.contains("/claude/versions/") || name == "claude" { return .claudeCode }
        if name == "codex" || (path.contains("/codex/") && name.hasPrefix("codex")) { return .codex }
        if name == "cursor-agent" { return .cursorAgent }
        if name == "opencode" { return .openCode }
        let scripts = arguments.dropFirst().prefix(2).map { ($0 as NSString).lastPathComponent }
        if scripts.contains("gemini") { return .geminiCLI }
        if scripts.contains("aider") { return .aider }
        return nil
    }

    /// Desktop apps from the same vendor, used to borrow a recognisable logo.
    var companionBundleIDs: [String] {
        switch self {
        case .claudeCode: return ["com.anthropic.claudefordesktop"]
        case .codex: return ["com.openai.codex", "com.openai.chat"]
        case .geminiCLI: return ["com.google.GeminiMacOS"]
        case .cursorAgent: return ["com.todesktop.230313mzl4w4u92"]
        case .aider, .openCode: return []
        }
    }
}
