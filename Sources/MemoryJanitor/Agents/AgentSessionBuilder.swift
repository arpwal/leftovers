import Darwin

/// Groups the process list into agent sessions.
struct AgentSessionBuilder {
    private let snapshots: [ProcessSnapshot]
    private let children: [pid_t: [ProcessSnapshot]]
    private let byPid: [pid_t: ProcessSnapshot]
    private let arguments: (pid_t) -> [String]

    init(_ snapshots: [ProcessSnapshot], arguments: @escaping (pid_t) -> [String] = { ProcessArguments.read($0) ?? [] }) {
        self.snapshots = snapshots
        self.children = Dictionary(grouping: snapshots, by: \.ppid)
        self.byPid = Dictionary(snapshots.map { ($0.pid, $0) }, uniquingKeysWith: { a, _ in a })
        self.arguments = arguments
    }

    func sessions() -> [AgentSession] {
        let roots = snapshots.compactMap { snapshot -> (AgentKind, ProcessSnapshot)? in
            guard snapshot.kind == .commandLine else { return nil }
            let kind = AgentKind.detect(path: snapshot.executablePath, name: snapshot.name,
                                        arguments: needsArguments(snapshot) ? arguments(snapshot.pid) : [])
            return kind.map { ($0, snapshot) }
        }
        let rootPids = Set(roots.map(\.1.pid))
        // A nested agent (a sub-agent spawned by another) belongs to its parent session.
        return roots
            .filter { !hasAncestor(in: rootPids, $0.1) }
            .map { session(kind: $0.0, root: $0.1) }
            .sorted { $0.totalFootprint > $1.totalFootprint }
    }

    private func session(kind: AgentKind, root: ProcessSnapshot) -> AgentSession {
        let members = descendants(of: root)
        let servers = members.dropFirst().compactMap { member in
            ToolServerLabel.label(for: arguments(member.pid)).map {
                ToolServerProcess(name: $0, footprintBytes: member.footprintBytes)
            }
        }
        return AgentSession(kind: kind, root: root, members: members, toolServers: servers)
    }

    /// Only interpreters need argv to be recognised (gemini/aider run as node/python).
    private func needsArguments(_ snapshot: ProcessSnapshot) -> Bool {
        ["node", "Python"].contains(snapshot.name) || snapshot.name.hasPrefix("python")
    }

    private func descendants(of root: ProcessSnapshot) -> [ProcessSnapshot] {
        var result = [root]
        var queue = [root.pid]
        while let pid = queue.popLast() {
            for child in children[pid] ?? [] where child.pid != pid {
                result.append(child)
                queue.append(child.pid)
            }
        }
        return result
    }

    private func hasAncestor(in pids: Set<pid_t>, _ snapshot: ProcessSnapshot) -> Bool {
        var parent = snapshot.ppid
        for _ in 0..<64 {
            if pids.contains(parent) { return true }
            guard parent > 1, let next = byPid[parent] else { return false }
            parent = next.ppid
        }
        return false
    }
}
