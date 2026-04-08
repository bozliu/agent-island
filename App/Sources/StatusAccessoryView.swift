import SwiftUI

public struct StatusAccessoryView: View {
    @ObservedObject private var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.92))
                    .frame(width: 18, height: 12)

                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color(red: 0.45, green: 0.92, blue: 0.62))
                    Rectangle()
                        .fill(Color(red: 0.98, green: 0.70, blue: 0.34))
                    Rectangle()
                        .fill(Color(red: 0.45, green: 0.72, blue: 1.00))
                }
                .frame(width: 8, height: 4)
            }

            Text(model.attentionSessions.isEmpty ? "Live" : "\(model.attentionSessions.count)")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Circle()
                .fill(model.attentionSessions.isEmpty ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.94),
                            Color(red: 0.14, green: 0.15, blue: 0.20),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
    }
}
