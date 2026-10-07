internal import Darwin
internal import Foundation

/// Decides whether an OSC 52 clipboard write from a remote terminal may set
/// this Mac's clipboard, from the `terminal.trustedClipboardWriteHosts`
/// setting.
///
/// Remote terminals (`cmux ssh` mirror panes and `cmux ssh-tmux` mirror
/// panes) carry untrusted output: anything printed on the host could replace
/// the clipboard, so their OSC 52 writes are dropped by default. The user
/// lists hosts they trust as `ssh_config`-style `Host` globs, matched against
/// the connection's SSH destination and, when present, its resolved
/// `HostName`, the same way `terminal.uploadCommands` matches a host.
public struct TerminalRemoteClipboardWriteTrust: Equatable, Sendable {
    /// `ssh_config`-style host globs (`*`, `?`; no pattern lists or `!`).
    public var hostPatterns: [String]

    /// Creates a trust policy from host patterns. Blank patterns are dropped.
    public init(hostPatterns: [String]) {
        self.hostPatterns = hostPatterns
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Creates a trust policy from the newline-joined form the settings file
    /// store writes to `UserDefaults` for string-array settings.
    public init(newlineSeparated storage: String) {
        self.init(hostPatterns: storage.components(separatedBy: "\n"))
    }

    /// Whether any of `hosts` matches a trusted pattern.
    ///
    /// - Parameter hosts: The SSH destination of the remote connection and,
    ///   when known, its resolved `HostName`. Each is normalized before
    ///   matching; see ``normalizedHost(_:)``. An empty list is never trusted.
    public func trusts(hosts: [String]) -> Bool {
        guard !hostPatterns.isEmpty else { return false }
        let normalizedHosts = hosts.map(Self.normalizedHost).filter { !$0.isEmpty }
        guard !normalizedHosts.isEmpty else { return false }
        return hostPatterns.contains { pattern in
            normalizedHosts.contains { Self.hostMatches(pattern: pattern, host: $0) }
        }
    }

    /// Normalizes an SSH destination to the host component used for matching:
    /// strips a leading `user@`, unwraps IPv6 brackets (`[::1]` → `::1`), and
    /// lowercases. A bare `host:port` is left as-is; cmux carries the port
    /// separately, so destinations here are bare hosts in practice.
    public static func normalizedHost(_ destination: String) -> String {
        var value = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if let atIndex = value.lastIndex(of: "@") {
            value = String(value[value.index(after: atIndex)...])
        }
        if value.hasPrefix("["), let close = value.firstIndex(of: "]") {
            value = String(value[value.index(after: value.startIndex)..<close])
        }
        return value.lowercased()
    }

    /// `ssh_config`-style glob match via POSIX `fnmatch`. The host is already
    /// lowercased, so the pattern is lowercased to match.
    public static func hostMatches(pattern: String, host: String) -> Bool {
        let loweredPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !loweredPattern.isEmpty, !host.isEmpty else { return false }
        return loweredPattern.withCString { patternPtr in
            host.withCString { hostPtr in
                fnmatch(patternPtr, hostPtr, 0) == 0
            }
        }
    }
}
