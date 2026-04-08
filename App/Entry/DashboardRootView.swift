import SwiftUI
import AgentIslandUI

struct DashboardRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.showOnboarding {
                OnboardingView(model: model)
            } else {
                SettingsWindowView(model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .animation(.spring(response: 0.26, dampingFraction: 0.9), value: model.showOnboarding)
    }
}
