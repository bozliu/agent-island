import AppKit
import AgentCore
import Localization
import SwiftUI

public struct OnboardingView: View {
    @ObservedObject private var model: AppModel
    @State private var step: OnboardingStep = .welcome
    @State private var enabledAgents: Set<String> = Set(AgentSource.firstClassProductSources.map(\.displayName))
    @State private var enabledTerminals: Set<String> = ["Terminal.app"]

    private let orderedSteps: [OnboardingStep] = [.welcome, .monitor, .approve, .complete, .allSet]

    public init(model: AppModel) {
        self.model = model
    }

    private var resolvedLocale: AppLocale {
        model.locale == .automatic ? AppCopy.currentLocale() : model.locale
    }

    private var featureIndex: Int? {
        switch step {
        case .monitor: 0
        case .approve: 1
        case .complete: 2
        default: nil
        }
    }

    public var body: some View {
        ZStack {
            onboardingBackground

            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 36)

                islandHeader

                Spacer(minLength: 24)

                mainStage
                    .frame(maxWidth: 1080, maxHeight: .infinity)

                controls
                    .padding(.top, 24)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 32)
        }
        .frame(minWidth: 1180, minHeight: 760)
    }

    private var onboardingBackground: some View {
        ZStack {
            if let url = Bundle.main.url(forResource: "onboarding-wallpaper", withExtension: "jpg"),
               let image = NSImage(contentsOf: url),
               image.isValid,
               image.size.width > 100,
               image.size.height > 100 {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 1.8)
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.16, blue: 0.42),
                        Color(red: 0.34, green: 0.44, blue: 0.83),
                        Color(red: 0.92, green: 0.70, blue: 0.47),
                        Color(red: 0.46, green: 0.36, blue: 0.74),
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                .ignoresSafeArea()
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.44),
                            Color.black.opacity(0.12),
                            Color.black.opacity(0.38),
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .ignoresSafeArea()
        }
    }

    private var islandHeader: some View {
        HStack(spacing: 16) {
            if let iconURL = Bundle.main.url(forResource: "extension-icon", withExtension: "png"),
               let icon = NSImage(contentsOf: iconURL),
               icon.isValid {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text("Agent Island")
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.black.opacity(0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.97, green: 0.53, blue: 0.74, opacity: 0.78),
                                    Color(red: 0.36, green: 0.49, blue: 1.00, opacity: 0.82),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.36), radius: 22, y: 10)
    }

    @ViewBuilder
    private var mainStage: some View {
        switch step {
        case .welcome:
            welcomeStage
        case .monitor:
            featureStage(
                counter: "1 / 4",
                title: copy(
                    en: "All your AI agents, one Dynamic Island.",
                    zh: "所有 AI Agent，都在一座灵动岛上。",
                    ja: "すべての AI エージェントを、一つの島で。",
                    ko: "모든 AI 에이전트를 하나의 섬에서."
                ),
                subtitle: copy(
                    en: "Terminals, desktop apps, and IDE sessions stay visible without breaking your flow.",
                    zh: "终端、桌面应用和 IDE 会话持续可见，不再打断你的工作流。",
                    ja: "ターミナルも IDE も、流れを切らずに同じ場所で把握できます。",
                    ko: "터미널과 IDE 세션을 흐름을 끊지 않고 한곳에서 볼 수 있습니다."
                ),
                panel: AnyView(monitorPreview)
            )
        case .approve:
            featureStage(
                counter: "2 / 4",
                title: copy(
                    en: "Approve without switching windows.",
                    zh: "不用切窗，直接审批。",
                    ja: "ウィンドウを切り替えずに承認。",
                    ko: "창을 전환하지 않고 바로 승인."
                ),
                subtitle: copy(
                    en: "When an agent needs permission, the island expands and keeps the decision right in front of you.",
                    zh: "当 Agent 需要权限时，灵动岛会自动展开，把决策直接送到你面前。",
                    ja: "権限が必要になると島が展開し、その場で判断できます。",
                    ko: "권한이 필요해지면 섬이 펼쳐져 바로 결정할 수 있습니다."
                ),
                panel: AnyView(approvalPreview)
            )
        case .complete:
            featureStage(
                counter: "3 / 4",
                title: copy(
                    en: "Know the moment it is done.",
                    zh: "任务完成的那一刻，立刻知道。",
                    ja: "完了した瞬間を見逃さない。",
                    ko: "끝나는 순간을 바로 알 수 있습니다."
                ),
                subtitle: copy(
                    en: "Finished tasks surface automatically, with sound and a clean summary instead of another buried terminal tab.",
                    zh: "任务完成会自动浮出水面，配上音效和清晰摘要，不再埋在终端标签页里。",
                    ja: "完了は自動で浮かび上がり、音と要約で気づけます。",
                    ko: "완료된 작업은 자동으로 떠오르고, 소리와 요약으로 알려줍니다."
                ),
                panel: AnyView(completionPreview)
            )
        case .allSet:
            allSetStage
        }
    }

    private func featureStage(counter: String, title: String, subtitle: String, panel: AnyView) -> some View {
        VStack(spacing: 28) {
            panel
                .frame(maxHeight: 360)

            VStack(spacing: 10) {
                Text(counter)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.52))
                Text(title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.74))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 700)
            }
        }
    }

    private var welcomeStage: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            demoNotch(status: copy(en: "Monitoring your coding agents", zh: "正在监控你的编码 Agent", ja: "コーディングエージェントを監視中", ko: "코딩 에이전트를 모니터링 중"))
                .padding(.bottom, 12)

            VStack(spacing: 16) {
                Text(copy(
                    en: "A Dynamic Island for your AI coding tools",
                    zh: "为你的 AI 编码工具打造灵动岛",
                    ja: "AI コーディングツールのための Dynamic Island",
                    ko: "AI 코딩 도구를 위한 Dynamic Island"
                ))
                .font(.system(size: 42, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 760)

                Text(copy(
                    en: "Keep Claude Code, Codex CLI, Gemini CLI, and OpenCode visible in one ambient layer above your work.",
                    zh: "把 Claude Code、Codex CLI、Gemini CLI 和 OpenCode 聚合到工作区上方的一层环境界面里。",
                    ja: "Claude Code、Codex CLI、Gemini CLI、OpenCode を、作業の上に浮かぶ一つの層へ。",
                    ko: "Claude Code, Codex CLI, Gemini CLI, OpenCode 를 작업 위 한 레이어에 모아 둡니다."
                ))
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.74))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 760)
            }

            Spacer(minLength: 12)
        }
    }

    private var allSetStage: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                   let icon = NSImage(contentsOf: iconURL),
                   icon.isValid {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 78, height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Text(copy(en: "All Set", zh: "一切就绪", ja: "準備完了", ko: "모든 준비 완료"))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(copy(
                    en: "Agent Island detected your tools and prepared the island for daily coding.",
                    zh: "Agent Island 已检测到你的工具，并为日常编码准备好了整座灵动岛。",
                    ja: "ツールを検出し、毎日のコーディング用に島を整えました。",
                    ko: "도구를 감지했고, 일상 코딩용 섬을 준비했습니다."
                ))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.74))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 700)
            }

            VStack(spacing: 18) {
                onboardingSection(title: copy(en: "AI Agents", zh: "AI 助手", ja: "AI エージェント", ko: "AI 에이전트")) {
                    VStack(spacing: 0) {
                        ForEach(AgentSource.firstClassProductSources.map(\.displayName), id: \.self) { agent in
                            toggleRow(label: agent, isOn: binding(for: agent, in: $enabledAgents))
                        }
                    }
                }

                onboardingSection(title: copy(en: "Terminals", zh: "终端", ja: "ターミナル", ko: "터미널")) {
                    VStack(spacing: 0) {
                        toggleRow(label: "Terminal.app", isOn: binding(for: "Terminal.app", in: $enabledTerminals))
                    }
                }

                onboardingSection(title: copy(en: "General", zh: "通用", ja: "一般", ko: "일반")) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $model.launchAtLoginEnabled) {
                            Text(copy(en: "Launch at Login", zh: "登录时启动", ja: "ログイン時に起動", ko: "로그인 시 실행"))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .toggleStyle(.switch)

                        Toggle(isOn: $model.autoHideWhenIdle) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(copy(en: "Auto Hide When Idle", zh: "空闲时自动隐藏", ja: "アイドル時に自動で隠す", ko: "유휴 시 자동 숨김"))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(copy(
                                    en: "Hide the island when no supported live sessions are running.",
                                    zh: "当没有受支持的实时会话在运行时，自动隐藏灵动岛。",
                                    ja: "サポート対象のライブセッションがないときは島を隠します。",
                                    ko: "지원되는 라이브 세션이 없으면 섬을 자동으로 숨깁니다."
                                ))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.62))
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
            }
            .frame(maxWidth: 720)
        }
    }

    private func onboardingSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.78))
            content()
        }
        .padding(18)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Label {
                Text(label)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            } icon: {
                Image(systemName: isOn.wrappedValue ? "checkmark" : "circle")
                    .foregroundStyle(isOn.wrappedValue ? Color.green : Color.white.opacity(0.42))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var controls: some View {
        VStack(spacing: 16) {
            indicatorRow

            HStack(spacing: 14) {
                if step != .welcome {
                    Button(copy(en: "Back", zh: "上一步", ja: "戻る", ko: "뒤로")) {
                        move(delta: -1)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(.white)
                }

                Button(primaryButtonTitle) {
                    primaryAction()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 42)
                .padding(.vertical, 16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(Color.black.opacity(0.88))
                .font(.system(size: 20, weight: .black, design: .rounded))

                if step != .allSet {
                    Button(copy(en: "Skip", zh: "跳过", ja: "スキップ", ko: "건너뛰기")) {
                        step = .allSet
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .padding(.horizontal, 8)
                }
            }
        }
    }

    private var indicatorRow: some View {
        HStack(spacing: 10) {
            ForEach(orderedSteps.indices, id: \.self) { index in
                Circle()
                    .fill(orderedSteps[index] == step ? Color.white : Color.white.opacity(0.28))
                    .frame(width: orderedSteps[index] == step ? 10 : 8, height: orderedSteps[index] == step ? 10 : 8)
            }
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome:
            return copy(en: "Get Started", zh: "开始使用", ja: "はじめる", ko: "시작하기")
        case .allSet:
            return copy(en: "Start Vibing", zh: "开始使用", ja: "使い始める", ko: "바로 시작")
        default:
            return copy(en: "Next", zh: "下一步", ja: "次へ", ko: "다음")
        }
    }

    private func primaryAction() {
        switch step {
        case .allSet:
            model.dismissOnboarding()
        default:
            move(delta: 1)
        }
    }

    private func move(delta: Int) {
        guard let current = orderedSteps.firstIndex(of: step) else { return }
        let nextIndex = min(max(current + delta, 0), orderedSteps.count - 1)
        step = orderedSteps[nextIndex]
    }

    private func binding(for value: String, in set: Binding<Set<String>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(value) },
            set: { isEnabled in
                if isEnabled {
                    set.wrappedValue.insert(value)
                } else {
                    set.wrappedValue.remove(value)
                }
            }
        )
    }

    private func copy(en: String, zh: String, ja: String, ko: String) -> String {
        switch resolvedLocale {
        case .zhHans:
            return zh
        case .ja:
            return ja
        case .ko:
            return ko
        default:
            return en
        }
    }

    private func demoNotch(status: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(status)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("Codex")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }

            Text(copy(en: "Need your attention", zh: "需要你的关注", ja: "対応が必要です", ko: "주의가 필요합니다"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.66))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 380)
        .background(Color.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.34), radius: 28, y: 10)
    }

    private var monitorPreview: some View {
        ZStack {
            demoNotch(status: copy(en: "checkout-api · fix checkout bug", zh: "checkout-api · 修复结账 bug", ja: "checkout-api · 決済バグ修正", ko: "checkout-api · 결제 버그 수정"))
                .offset(y: -118)

            fauxWindow(
                title: "claude — fix-auth-bug",
                rows: [
                    row("Found the issue — token validation skips expiry check.", tint: .green),
                    row("Running tests to verify the fix.", tint: .white.opacity(0.82)),
                    row("All checks passing.", tint: .green),
                ]
            )
            .frame(width: 520, height: 290)
        }
    }

    private var approvalPreview: some View {
        ZStack {
            demoNotch(status: copy(en: "Permission request surfaced", zh: "权限请求已浮出", ja: "権限リクエストが表示されました", ko: "권한 요청이 떠올랐습니다"))
                .offset(y: -128)

            VStack(spacing: 0) {
                fauxWindow(
                    title: "codex — backend-server",
                    rows: [
                        row("Edit(src/auth/middleware.ts)", tint: .white),
                        row("- jwt.verify(token);", tint: .red.opacity(0.92)),
                        row("+ verify(token) // adds expiry validation", tint: .green.opacity(0.95)),
                    ]
                )
                .frame(width: 520, height: 250)

                HStack(spacing: 10) {
                    actionPill(copy(en: "Deny", zh: "拒绝", ja: "拒否", ko: "거부"), accent: .white.opacity(0.18))
                    actionPill(copy(en: "Allow Once", zh: "允许一次", ja: "一度だけ許可", ko: "한 번 허용"), accent: .white.opacity(0.22))
                    actionPill(copy(en: "Always Allow", zh: "始终允许", ja: "常に許可", ko: "항상 허용"), accent: .red.opacity(0.75))
                }
                .offset(y: -24)
            }
        }
    }

    private var completionPreview: some View {
        ZStack {
            demoNotch(status: copy(en: "Fix landed", zh: "修复已完成", ja: "修正完了", ko: "수정 완료"))
                .offset(y: -126)

            fauxWindow(
                title: "claude — add dark mode",
                rows: [
                    row("Edit(src/styles/theme.css)", tint: .green),
                    row("Done (+24 −3 lines)", tint: .white.opacity(0.82)),
                    row("Dark mode support added.", tint: .green),
                ]
            )
            .frame(width: 520, height: 250)
        }
    }

    private func fauxWindow(title: String, rows: [PreviewRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(Color.red.opacity(0.86)).frame(width: 10, height: 10)
                Circle().fill(Color.orange.opacity(0.86)).frame(width: 10, height: 10)
                Circle().fill(Color.green.opacity(0.86)).frame(width: 10, height: 10)
                Spacer()
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.42))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.04))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows) { row in
                    Text(row.text)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(row.tint)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 28, y: 10)
    }

    private func actionPill(_ title: String, accent: Color) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ text: String, tint: Color) -> PreviewRow {
        PreviewRow(text: text, tint: tint)
    }
}

private enum OnboardingStep: CaseIterable {
    case welcome
    case monitor
    case approve
    case complete
    case allSet
}

private struct PreviewRow: Identifiable {
    let id = UUID()
    let text: String
    let tint: Color
}
