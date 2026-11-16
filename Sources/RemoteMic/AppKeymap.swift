import Foundation

/// One sparse binding inside an app-specific mapping. A missing `(button, trigger)`
/// inherits the global mapping; an explicit `.disabled` action never falls through.
struct AppKeymapBinding: Codable, Equatable, Identifiable {
    var keymapID: UUID
    var button: RemoteButton
    var trigger: ButtonTrigger
    var configured: ConfiguredButtonAction

    var id: String {
        "\(keymapID.uuidString).\(button.rawValue).\(trigger.rawValue)"
    }
}

/// Buttons that belong to one application. While that application is frontmost
/// these bindings are used; every other application uses the global mapping.
struct AppKeymapProfile: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var bundleIdentifier: String
    var displayName: String
    var bindings: [AppKeymapBinding] = []
    var holdModes: [String: RemoteButtonHoldMode] = [:]

    func binding(button: RemoteButton, trigger: ButtonTrigger) -> ConfiguredButtonAction? {
        bindings.first { $0.button == button && $0.trigger == trigger }?.configured
    }

    func holdMode(button: RemoteButton) -> RemoteButtonHoldMode? {
        holdModes[button.rawValue]
    }
}

/// Persisted app-specific mappings. There is deliberately no manual/automatic
/// switch and no fallback profile: one profile per application, selected by the
/// frontmost app.
struct AppKeymapState: Codable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int = AppKeymapState.currentSchemaVersion
    var profiles: [AppKeymapProfile] = []

    func profile(id: UUID?) -> AppKeymapProfile? {
        guard let id else { return nil }
        return profiles.first { $0.id == id }
    }

    func profile(forBundleIdentifier bundleIdentifier: String?) -> AppKeymapProfile? {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return nil }
        return profiles.first { $0.bundleIdentifier == bundleIdentifier }
    }
}

/// Captured once when a physical button goes down. The same value follows the
/// whole gesture (single/double/long/hold/repeat/release) so a foreground switch
/// cannot mix two different mappings.
struct KeymapContext: Equatable {
    let frontmostBundleIdentifier: String?

    static let none = KeymapContext(frontmostBundleIdentifier: nil)
}

enum AppKeymapResolver {
    /// Bundle identifiers are matched exactly. Empty or malformed identifiers
    /// are rejected on import and ignored at runtime.
    static func isValidBundleIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 255 else { return false }
        return value.range(of: #"^[A-Za-z0-9][A-Za-z0-9.-]*$"#, options: .regularExpression) != nil
    }

    static func activeProfileID(
        state: AppKeymapState,
        context: KeymapContext,
        selfBundleIdentifier: String = AppIdentity.bundleIdentifier
    ) -> UUID? {
        guard let bundle = context.frontmostBundleIdentifier,
              !bundle.isEmpty,
              bundle != selfBundleIdentifier
        else { return nil }
        return state.profiles.first { $0.bundleIdentifier == bundle }?.id
    }

    static func binding(
        keymapID: UUID,
        button: RemoteButton,
        trigger: ButtonTrigger,
        in profiles: [AppKeymapProfile]
    ) -> ConfiguredButtonAction? {
        guard RemoteButton.appKeymapCases.contains(button) else { return nil }
        guard let profile = profiles.first(where: { $0.id == keymapID }) else { return nil }
        return profile.binding(button: button, trigger: trigger)
    }

    static func holdMode(
        keymapID: UUID,
        button: RemoteButton,
        in profiles: [AppKeymapProfile]
    ) -> RemoteButtonHoldMode? {
        guard RemoteButton.appKeymapCases.contains(button) else { return nil }
        return profiles.first { $0.id == keymapID }?.holdMode(button: button)
    }

    /// Drops malformed entries from imported or decoded state. Runtime must only
    /// ever see a state that passed through here.
    static func validatedState(
        _ state: AppKeymapState,
        selfBundleIdentifier: String = AppIdentity.bundleIdentifier
    ) -> (state: AppKeymapState, rejected: Bool) {
        var rejected = false
        var seenProfileIDs = Set<UUID>()
        var seenBundleIdentifiers = Set<String>()
        var profiles: [AppKeymapProfile] = []

        for original in state.profiles {
            guard seenProfileIDs.insert(original.id).inserted else {
                rejected = true
                continue
            }
            let bundleIdentifier = original.bundleIdentifier
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidBundleIdentifier(bundleIdentifier),
                  bundleIdentifier != selfBundleIdentifier,
                  seenBundleIdentifiers.insert(bundleIdentifier).inserted
            else {
                rejected = true
                continue
            }

            let displayName = original.displayName
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedName = displayName.isEmpty ? bundleIdentifier : displayName

            var seenBindings = Set<String>()
            var bindings: [AppKeymapBinding] = []
            for binding in original.bindings {
                guard binding.keymapID == original.id,
                      RemoteButton.appKeymapCases.contains(binding.button),
                      seenBindings.insert(binding.id).inserted
                else {
                    rejected = true
                    continue
                }
                let configured = binding.configured.normalizedForExecution
                if configured != binding.configured {
                    rejected = true
                }
                bindings.append(AppKeymapBinding(
                    keymapID: original.id,
                    button: binding.button,
                    trigger: binding.trigger,
                    configured: configured
                ))
            }

            var holdModes: [String: RemoteButtonHoldMode] = [:]
            for (rawButton, mode) in original.holdModes {
                guard let button = RemoteButton(rawValue: rawButton),
                      RemoteButton.appKeymapCases.contains(button)
                else {
                    rejected = true
                    continue
                }
                holdModes[rawButton] = mode
            }

            profiles.append(AppKeymapProfile(
                id: original.id,
                bundleIdentifier: bundleIdentifier,
                displayName: resolvedName,
                bindings: bindings,
                holdModes: holdModes
            ))
        }

        if state.schemaVersion != AppKeymapState.currentSchemaVersion {
            rejected = true
        }
        return (
            AppKeymapState(
                schemaVersion: AppKeymapState.currentSchemaVersion,
                profiles: profiles
            ),
            rejected
        )
    }
}

extension RemoteButton {
    /// Buttons an app-specific mapping is allowed to override. Menu, TV and the
    /// voice key keep using the global mapping.
    static let appKeymapCases: [RemoteButton] = [
        .power, .up, .down, .left, .right, .ok, .back, .home,
        .volumeUp, .volumeDown,
    ]
}
