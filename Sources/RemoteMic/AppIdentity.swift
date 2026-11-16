import Foundation

/// Identity of the running build.
///
/// The development edition is packaged with its own bundle identifier and
/// `SayAllDevelopmentEdition` flag. It must not share the single-instance
/// lock, logs, or user data with the official app, otherwise both builds would
/// block each other while still installed side by side.
enum AppIdentity {
    static let bundleIdentifier: String =
        Bundle.main.bundleIdentifier ?? "com.hd838a.RemoteMic"

    static let isDevelopmentEdition: Bool =
        Bundle.main.object(forInfoDictionaryKey: "SayAllDevelopmentEdition") as? Bool == true

    /// Directory name under Application Support and Logs. The official app keeps
    /// the historical "RemoteMic" name so existing data continues to resolve.
    static var storageComponent: String {
        isDevelopmentEdition ? "RemoteMicDev" : "RemoteMic"
    }

    /// Namespace for diagnostic/public events under Application Support.
    static var diagnosticComponent: String {
        isDevelopmentEdition ? "SayAllDev" : "SayAll"
    }
}
