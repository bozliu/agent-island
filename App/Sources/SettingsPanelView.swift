import SwiftUI

public struct SettingsPanelView: View {
    @ObservedObject private var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Controls")
                .font(.headline)

            HStack {
                Button("Onboarding") {
                    model.showOnboardingFlow()
                }
                Button("Diagnostics") {
                    Task { await model.exportDiagnostics() }
                }
                Button("Updates") {
                    Task { await model.checkForUpdates() }
                }
            }

            HStack {
                Toggle("Usage", isOn: $model.showUsage)
                Toggle("Detail", isOn: $model.showAgentDetail)
            }

            HStack {
                Toggle("Sound", isOn: Binding(
                    get: { model.soundSettings.isEnabled },
                    set: { newValue in
                        model.soundSettings = .init(
                            isEnabled: newValue,
                            volume: model.soundSettings.volume,
                            selectedSoundPackID: model.soundSettings.selectedSoundPackID
                        )
                    }
                ))
                Toggle("Auto hide", isOn: $model.autoHideWhenIdle)
            }

            HStack {
                Toggle("Completed", isOn: $model.showCompletedTasks)
                Toggle("Probe filter", isOn: $model.autoDetectProbeSessions)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
