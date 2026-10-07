import CmuxTerminalCore
import Testing

@Suite
struct TerminalRemoteClipboardWriteTrustTests {
    @Test func trustsNothingByDefault() {
        let trust = TerminalRemoteClipboardWriteTrust(hostPatterns: [])
        #expect(!trust.trusts(hosts: ["dev-box"]))
        #expect(!trust.trusts(hosts: []))
    }

    @Test func trustsAnExactDestination() {
        let trust = TerminalRemoteClipboardWriteTrust(hostPatterns: ["dev-box"])
        #expect(trust.trusts(hosts: ["dev-box"]))
        #expect(!trust.trusts(hosts: ["other-box"]))
    }

    @Test func matchesSSHConfigStyleGlobs() {
        let trust = TerminalRemoteClipboardWriteTrust(hostPatterns: ["*.corp.example.com", "dev-?"])
        #expect(trust.trusts(hosts: ["dsk.corp.example.com"]))
        #expect(trust.trusts(hosts: ["dev-1"]))
        #expect(!trust.trusts(hosts: ["dev-10"]))
        #expect(!trust.trusts(hosts: ["corp.example.com"]))
    }

    @Test func aCatchAllPatternTrustsEveryRemoteHost() {
        let trust = TerminalRemoteClipboardWriteTrust(hostPatterns: ["*"])
        #expect(trust.trusts(hosts: ["anything"]))
        #expect(!trust.trusts(hosts: []), "a surface with no remote host is never a remote write")
    }

    @Test func normalizesUserAndIPv6BracketsAndCase() {
        let trust = TerminalRemoteClipboardWriteTrust(hostPatterns: ["Dev-Box", "::1"])
        #expect(trust.trusts(hosts: ["alice@DEV-BOX"]))
        #expect(trust.trusts(hosts: ["[::1]"]))
        #expect(TerminalRemoteClipboardWriteTrust.normalizedHost("alice@[::1]") == "::1")
    }

    @Test func matchesTheResolvedHostNameAsWellAsTheAlias() {
        let trust = TerminalRemoteClipboardWriteTrust(hostPatterns: ["real.example.com"])
        #expect(trust.trusts(hosts: ["localhost", "real.example.com"]))
    }

    @Test func dropsBlankPatternsAndReadsNewlineSeparatedStorage() {
        let trust = TerminalRemoteClipboardWriteTrust(newlineSeparated: " \ndev-box\n\n")
        #expect(trust.hostPatterns == ["dev-box"])
        #expect(trust.trusts(hosts: ["dev-box"]))
        #expect(!TerminalRemoteClipboardWriteTrust(newlineSeparated: "").trusts(hosts: ["dev-box"]))
    }
}
