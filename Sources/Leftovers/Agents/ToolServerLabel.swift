import Foundation

/// Names a tool (MCP) server from its arguments, e.g.
/// `npm exec @google-cloud/observability-mcp` → "observability-mcp".
enum ToolServerLabel {
    private static let scriptExtensions: Set<String> = ["js", "mjs", "cjs", "ts", "py"]

    static func label(for arguments: [String]) -> String? {
        for argument in arguments.dropFirst() {
            let component = stripScriptExtension((argument as NSString).lastPathComponent)
            guard component.localizedCaseInsensitiveContains("mcp") else { continue }
            // Drop a trailing "@version" but keep a leading "@scope".
            if let at = component.lastIndex(of: "@"), at != component.startIndex {
                return String(component[..<at])
            }
            return component
        }
        return nil
    }

    private static func stripScriptExtension(_ name: String) -> String {
        let ext = (name as NSString).pathExtension
        return scriptExtensions.contains(ext) ? (name as NSString).deletingPathExtension : name
    }
}
