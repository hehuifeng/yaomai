import AppKit
import UniformTypeIdentifiers

/// Shared "choose an application" panel. The existing per-feature copies can
/// migrate here without changing their stored data.
enum ApplicationPicker {
    struct Selection: Equatable {
        let bundleIdentifier: String
        let displayName: String
        let url: URL
    }

    static func chooseApplication(title: String, prompt: String) -> Selection? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier
        else { return nil }
        return Selection(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName(for: bundle, url: url),
            url: url
        )
    }

    static func displayName(for bundleIdentifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else { return bundleIdentifier }
        guard let bundle = Bundle(url: url) else {
            return FileManager.default.displayName(atPath: url.path)
        }
        return displayName(for: bundle, url: url)
    }

    static func icon(for bundleIdentifier: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private static func displayName(for bundle: Bundle, url: URL) -> String {
        (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? FileManager.default.displayName(atPath: url.path)
    }
}
