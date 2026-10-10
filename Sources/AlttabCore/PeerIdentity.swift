import Darwin
import Foundation
import Security

/// Confere quem está do outro lado do socket pela assinatura de código: só o alttab-host e o app,
/// assinados pelo mesmo time, conversam. Outro processo do mesmo usuário não lê abas nem miniaturas.
public enum PeerIdentity {
    public static let team = "8R7M224T7Y"
    public static let hostIdentifier = "br.inf.brusoft.alttab.host"
    public static let appIdentifier = "br.inf.brusoft.alttab"

    public static var hostRequirement: String { requirement(identifier: hostIdentifier) }
    public static var appRequirement: String { requirement(identifier: appIdentifier) }

    static func requirement(identifier: String) -> String {
        #"identifier "\#(identifier)" and anchor apple generic and certificate leaf[subject.OU] = "\#(team)""#
    }

    public static func verify(fd: Int32, requirement text: String) -> Bool {
        var token = audit_token_t()
        var size = socklen_t(MemoryLayout<audit_token_t>.size)
        guard getsockopt(fd, SOL_LOCAL, LOCAL_PEERTOKEN, &token, &size) == 0 else { return false }
        let tokenData = withUnsafeBytes(of: &token) { Data($0) }
        let attributes = [kSecGuestAttributeAudit: tokenData] as CFDictionary
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess, let code else { return false }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
              let requirement else { return false }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
}
