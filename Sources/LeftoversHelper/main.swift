import Foundation
import LeftoversHelperKit

// Leftovers' privileged helper: a launchd daemon registered by the app with
// SMAppService.daemon and approved once by the user in Login Items. It runs
// as root on demand and can do exactly one thing: restart fseventsd.

// An unsigned or ad-hoc build has no team to check clients against: refuse to serve.
guard let clientRequirement = SigningRequirement.forApp else {
    FileHandle.standardError.write(Data("LeftoversHelper: not signed with a Developer ID; refusing to run\n".utf8))
    exit(1)
}

let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
let delegate = HelperListenerDelegate()
listener.setConnectionCodeSigningRequirement(clientRequirement)
listener.delegate = delegate
listener.resume()
HelperActivity.shared.exitWhenIdle()
dispatchMain()
