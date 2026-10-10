import Foundation
import Testing
@testable import AlttabCore

@Suite(.serialized) struct PeerIdentityTests {
    private func connectedPair() throws -> (server: UnixSocket, connection: UnixSocket, client: UnixSocket, path: String) {
        let path = "/private/tmp/alttab-peer-\(UUID().uuidString.prefix(8)).sock"
        let server = try UnixSocket.listen(path: path)
        let client = try UnixSocket.connect(path: path)
        let connection = try server.accept()
        return (server, connection, client, path)
    }

    @Test func acceptsPeerMatchingRequirement() throws {
        let pair = try connectedPair()
        defer { pair.client.close(); pair.connection.close(); pair.server.close(); unlink(pair.path) }
        #expect(PeerIdentity.verify(fd: pair.connection.fd, requirement: "always"))
    }

    @Test func rejectsPeerWithOtherIdentity() throws {
        let pair = try connectedPair()
        defer { pair.client.close(); pair.connection.close(); pair.server.close(); unlink(pair.path) }
        #expect(!PeerIdentity.verify(fd: pair.connection.fd, requirement: #"identifier "br.inf.brusoft.alttab.host""#))
    }

    @Test func rejectsInvalidRequirementText() throws {
        let pair = try connectedPair()
        defer { pair.client.close(); pair.connection.close(); pair.server.close(); unlink(pair.path) }
        #expect(!PeerIdentity.verify(fd: pair.connection.fd, requirement: "isso não é requisito"))
    }

    @Test func requirementsPinTeamAndIdentifier() {
        #expect(PeerIdentity.hostRequirement.contains(#"identifier "br.inf.brusoft.alttab.host""#))
        #expect(PeerIdentity.appRequirement.contains(#"identifier "br.inf.brusoft.alttab""#))
        #expect(PeerIdentity.hostRequirement.contains("8R7M224T7Y"))
    }

    @Test func bridgeDirectoryIsPrivate() throws {
        try BridgePaths.prepareDirectory()
        let mode = try FileManager.default.attributesOfItem(atPath: BridgePaths.directory.path)[.posixPermissions] as? Int
        #expect(mode == 0o700)
    }
}
