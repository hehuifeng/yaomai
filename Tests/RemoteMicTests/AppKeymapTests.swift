import Foundation
import Testing
@testable import RemoteMic

@Suite("App keymap resolution")
struct AppKeymapTests {
    private func makeSettings() throws -> (AppSettings, UserDefaults, String) {
        let name = "SayAll.AppKeymap.\(UUID().uuidString)"
        let defaults = try #require(TestUserDefaults(suiteName: name))
        return (AppSettings(defaults: defaults), defaults, name)
    }

    private func makeProfile(
        id: UUID = UUID(),
        bundle: String = "com.apple.Safari",
        name: String = "Safari"
    ) -> AppKeymapProfile {
        AppKeymapProfile(id: id, bundleIdentifier: bundle, displayName: name)
    }

    @Test func frontmostAppSelectsItsOwnMapping() {
        let profileID = UUID()
        var state = AppKeymapState()
        state.profiles = [makeProfile(id: profileID)]

        let safari = KeymapContext(frontmostBundleIdentifier: "com.apple.Safari")
        #expect(AppKeymapResolver.activeProfileID(state: state, context: safari) == profileID)

        let finder = KeymapContext(frontmostBundleIdentifier: "com.apple.finder")
        #expect(AppKeymapResolver.activeProfileID(state: state, context: finder) == nil)

        let selfContext = KeymapContext(frontmostBundleIdentifier: AppIdentity.bundleIdentifier)
        #expect(AppKeymapResolver.activeProfileID(state: state, context: selfContext) == nil)
    }

    @Test func appMappingStartsFromTheGlobalMappingAndOnlyChangesWhatTheUserEdits() throws {
        let (settings, defaults, suite) = try makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }

        settings.setBaseBinding(
            ConfiguredButtonAction(action: .arrowLeft, shortcut: nil),
            for: .ok,
            trigger: .singleClick,
            profileID: nil
        )
        let profileID = try #require(settings.addAppKeymapProfile(
            for: "com.apple.Safari",
            displayName: "Safari",
            copyingBaseFromDevice: nil,
            copyBase: true
        ))
        let context = KeymapContext(frontmostBundleIdentifier: "com.apple.Safari")

        // Copied from the global mapping.
        #expect(settings.configuredAction(
            for: .ok,
            trigger: .singleClick,
            profileID: nil,
            keymapContext: context
        ).action == .arrowLeft)

        settings.setAppKeymapBinding(
            .disabled,
            keymapID: profileID,
            button: .ok,
            trigger: .singleClick
        )
        #expect(settings.configuredAction(
            for: .ok,
            trigger: .singleClick,
            profileID: nil,
            keymapContext: context
        ).action == .disabled)
    }

    @Test func addingTheSameAppReusesItsMapping() throws {
        let (settings, defaults, suite) = try makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = try #require(settings.addAppKeymapProfile(
            for: "com.apple.Safari",
            displayName: "Safari",
            copyingBaseFromDevice: nil
        ))
        let second = try #require(settings.addAppKeymapProfile(
            for: "com.apple.Safari",
            displayName: "Safari",
            copyingBaseFromDevice: nil
        ))
        #expect(first == second)
        #expect(settings.appKeymapProfiles.count == 1)
    }

    @Test func mappingPersistsAcrossReload() throws {
        let (settings, defaults, suite) = try makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }

        let profileID = try #require(settings.addAppKeymapProfile(
            for: "com.apple.Safari",
            displayName: "Safari",
            copyingBaseFromDevice: nil
        ))
        settings.setAppKeymapHoldMode(.repeatSingle, keymapID: profileID, button: .left)

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.appKeymapState == settings.appKeymapState)
        #expect(reloaded.appKeymapProfiles.count == 1)
    }

    @Test func invalidApplicationsAreDropped() {
        var state = AppKeymapState()
        state.profiles = [
            makeProfile(bundle: ""),
            makeProfile(bundle: "bad id"),
            makeProfile(bundle: AppIdentity.bundleIdentifier),
            makeProfile(bundle: "com.apple.Safari"),
            makeProfile(bundle: "com.apple.Safari"),
        ]
        let validated = AppKeymapResolver.validatedState(
            state,
            selfBundleIdentifier: AppIdentity.bundleIdentifier
        )
        #expect(validated.rejected)
        #expect(validated.state.profiles.map(\.bundleIdentifier) == ["com.apple.Safari"])
    }
}
