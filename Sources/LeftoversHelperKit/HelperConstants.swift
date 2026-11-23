import Foundation

/// Names and limits shared by the app and its privileged helper.
/// The helper's launchd plist (packaging/LaunchDaemons/) must use the same
/// label and Mach service name.
public enum HelperConstants {
    /// launchd label and XPC Mach service of the root helper.
    public static let machServiceName = "com.arpwal.leftovers.helper"
    /// File name of the plist in Contents/Library/LaunchDaemons/.
    public static let daemonPlistName = "com.arpwal.leftovers.helper.plist"
    /// Code-signing identifiers: the only client the helper accepts, and the helper itself.
    public static let appIdentifier = "com.arpwal.leftovers"
    public static let helperIdentifier = "com.arpwal.leftovers.helper"

    /// The one process the helper may signal.
    public static let fseventsdPath =
        "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/FSEvents.framework/Versions/A/Support/fseventsd"
    public static let fseventsdName = "fseventsd"

    /// fseventsd flushes its journals on SIGTERM; when it has grown to many GB
    /// that takes ~30 s, so it gets a generous grace period before SIGKILL.
    public static let terminateGracePeriod: TimeInterval = 60
}
