import Foundation

extension AppSettings {
    var appKeymapProfiles: [AppKeymapProfile] {
        appKeymapState.profiles
    }

    func appKeymapProfile(id: UUID?) -> AppKeymapProfile? {
        appKeymapState.profile(id: id)
    }

    func appKeymapProfile(forBundleIdentifier bundleIdentifier: String) -> AppKeymapProfile? {
        appKeymapState.profile(forBundleIdentifier: bundleIdentifier)
    }

    func appKeymapBinding(
        keymapID: UUID,
        button: RemoteButton,
        trigger: ButtonTrigger
    ) -> ConfiguredButtonAction? {
        AppKeymapResolver.binding(
            keymapID: keymapID,
            button: button,
            trigger: trigger,
            in: appKeymapState.profiles
        )
    }

    func appKeymapHoldMode(
        keymapID: UUID,
        button: RemoteButton
    ) -> RemoteButtonHoldMode? {
        AppKeymapResolver.holdMode(
            keymapID: keymapID,
            button: button,
            in: appKeymapState.profiles
        )
    }

    /// Resolves the app-specific mapping for the captured foreground app.
    /// `nil` means the global mapping should be used.
    func resolvedAppKeymapProfileID(for context: KeymapContext?) -> UUID? {
        guard let context else { return nil }
        return AppKeymapResolver.activeProfileID(
            state: appKeymapState,
            context: context
        )
    }

    /// True only when the resolved app mapping explicitly binds this button/trigger.
    /// Inherited entries do not count: native passthrough and repeat decisions
    /// must keep following the global mapping for them.
    func hasExplicitAppKeymapBinding(
        for button: RemoteButton,
        trigger: ButtonTrigger,
        context: KeymapContext?
    ) -> Bool {
        guard let keymapID = resolvedAppKeymapProfileID(for: context),
              RemoteButton.appKeymapCases.contains(button)
        else { return false }
        return appKeymapBinding(keymapID: keymapID, button: button, trigger: trigger) != nil
    }

    /// True only when the resolved app mapping stores an explicit hold mode for
    /// the button. Such a button must not take the native left/right passthrough.
    func hasExplicitAppKeymapHoldMode(
        for button: RemoteButton,
        context: KeymapContext?
    ) -> Bool {
        guard let keymapID = resolvedAppKeymapProfileID(for: context) else { return false }
        return appKeymapHoldMode(keymapID: keymapID, button: button) != nil
    }

    /// Creates (or returns the existing) mapping for one application. New
    /// mappings copy the global mapping so the page starts from what the user
    /// already knows, then only the buttons they change differ.
    @discardableResult
    func addAppKeymapProfile(
        for bundleIdentifier: String,
        displayName: String,
        copyingBaseFromDevice deviceID: UUID?,
        copyBase: Bool = true
    ) -> UUID? {
        let bundle = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AppKeymapResolver.isValidBundleIdentifier(bundle),
              bundle != AppIdentity.bundleIdentifier
        else { return nil }
        if let existing = appKeymapState.profile(forBundleIdentifier: bundle) {
            return existing.id
        }
        let profileID = UUID()
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        var bindings: [AppKeymapBinding] = []
        if copyBase {
            for button in RemoteButton.appKeymapCases {
                for trigger in ButtonTrigger.allCases {
                    let configured = configuredBaseAction(
                        for: button,
                        trigger: trigger,
                        profileID: deviceID
                    ).normalizedForExecution
                    bindings.append(AppKeymapBinding(
                        keymapID: profileID,
                        button: button,
                        trigger: trigger,
                        configured: configured
                    ))
                }
            }
        }
        appKeymapState.profiles.append(AppKeymapProfile(
            id: profileID,
            bundleIdentifier: bundle,
            displayName: name.isEmpty ? bundle : name,
            bindings: bindings
        ))
        return profileID
    }

    func removeAppKeymapProfile(id: UUID) {
        appKeymapState.profiles.removeAll { $0.id == id }
    }

    func setAppKeymapBinding(
        _ configured: ConfiguredButtonAction?,
        keymapID: UUID,
        button: RemoteButton,
        trigger: ButtonTrigger
    ) {
        guard RemoteButton.appKeymapCases.contains(button),
              let index = appKeymapState.profiles.firstIndex(where: { $0.id == keymapID })
        else { return }
        var bindings = appKeymapState.profiles[index].bindings
        bindings.removeAll { $0.button == button && $0.trigger == trigger }
        if let configured {
            bindings.append(AppKeymapBinding(
                keymapID: keymapID,
                button: button,
                trigger: trigger,
                configured: configured.normalizedForExecution
            ))
        }
        appKeymapState.profiles[index].bindings = bindings
    }

    func setAppKeymapHoldMode(
        _ mode: RemoteButtonHoldMode?,
        keymapID: UUID,
        button: RemoteButton
    ) {
        guard RemoteButton.appKeymapCases.contains(button),
              let index = appKeymapState.profiles.firstIndex(where: { $0.id == keymapID })
        else { return }
        if let mode {
            appKeymapState.profiles[index].holdModes[button.rawValue] = mode
        } else {
            appKeymapState.profiles[index].holdModes.removeValue(forKey: button.rawValue)
        }
    }

    func resetAppKeymapState() {
        appKeymapState = AppKeymapState()
    }
}
