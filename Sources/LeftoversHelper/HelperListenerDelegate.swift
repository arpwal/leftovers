import Foundation
import LeftoversHelperKit

/// Accepts XPC connections only from Leftovers signed by this helper's own
/// team (checked by the kernel-backed code-signing requirement, per
/// connection), and exports only `FseventsdHelperProtocol`.
final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard let requirement = SigningRequirement.forApp else { return false }
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: FseventsdHelperProtocol.self)
        connection.exportedObject = HelperService()
        connection.resume()
        HelperActivity.shared.touch()
        return true
    }
}
