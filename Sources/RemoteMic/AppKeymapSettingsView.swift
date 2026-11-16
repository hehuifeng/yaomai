import AppKit
import SwiftUI

/// Fixed bar above the mapping canvas.
///
/// The mental model is deliberately small: the global mapping applies everywhere,
/// and an app chip edits the buttons that app uses while it is frontmost. There is
/// no manual switch, no priority list and no fallback profile.
struct AppKeymapToolbar: View {
    @ObservedObject var settings: AppSettings
    @Binding var editingProfileID: UUID?
    let onEnableCustomMapping: () -> Void

    @EnvironmentObject private var localization: LocalizationStore
    @State private var deleteConfirmation = false

    var body: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip(
                        localization.text("app_keymap.bar.base"),
                        selected: editingProfileID == nil
                    ) {
                        editingProfileID = nil
                    }
                    ForEach(settings.appKeymapProfiles) { profile in
                        chip(profile.displayName, selected: editingProfileID == profile.id) {
                            editingProfileID = profile.id
                        }
                    }
                    Button {
                        addApplication()
                    } label: {
                        Label(localization.text("app_keymap.bar.add_app"), systemImage: "plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 2)
            }
            Spacer(minLength: 8)
            if !settings.customMappingEnabled {
                Text(localization.text("app_keymap.custom_mapping_off"))
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                Button(localization.text("app_keymap.custom_mapping_enable")) {
                    onEnableCustomMapping()
                }
                .buttonStyle(.borderless)
            } else if let profile = selectedProfile {
                Text(String(
                    format: localization.text("app_keymap.hint.app"),
                    profile.displayName
                ))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                Button(localization.text("app_keymap.bar.delete_app")) {
                    deleteConfirmation = true
                }
                .buttonStyle(.borderless)
            } else {
                Text(localization.text("app_keymap.hint.global"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .confirmationDialog(
            String(
                format: localization.text("app_keymap.delete.confirm"),
                selectedProfile?.displayName ?? ""
            ),
            isPresented: $deleteConfirmation
        ) {
            Button(localization.text("app_keymap.bar.delete_app"), role: .destructive) {
                deleteSelected()
            }
            Button(localization.text("common.action.cancel"), role: .cancel) {}
        } message: {
            Text("app_keymap.delete.detail")
        }
        .onChange(of: settings.appKeymapProfiles.map(\.id)) { ids in
            if let id = editingProfileID, !ids.contains(id) {
                editingProfileID = nil
            }
        }
    }

    private var selectedProfile: AppKeymapProfile? {
        settings.appKeymapProfile(id: editingProfileID)
    }

    private func addApplication() {
        guard let selection = ApplicationPicker.chooseApplication(
            title: localization.text("app_keymap.bar.add_app"),
            prompt: localization.text("common.action.ok")
        ) else { return }
        if let id = settings.addAppKeymapProfile(
            for: selection.bundleIdentifier,
            displayName: selection.displayName,
            copyingBaseFromDevice: settings.selectedRemoteProfileID,
            copyBase: true
        ) {
            editingProfileID = id
        }
    }

    private func deleteSelected() {
        guard let id = editingProfileID else { return }
        settings.removeAppKeymapProfile(id: id)
        editingProfileID = nil
    }

    private func chip(
        _ title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.06),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(
                        selected ? Color.accentColor.opacity(0.5) : Color.clear
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
