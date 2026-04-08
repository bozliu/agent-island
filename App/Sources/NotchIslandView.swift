import AgentCore
import AppKit
import ClaudeIslandRuntime
import Localization
import SwiftUI

public struct NotchIslandView: View {
    @ObservedObject private var model: AppModel
    @State private var collapseTask: Task<Void, Never>?
    @State private var inlineResponseText = ""

    public init(model: AppModel) {
        self.model = model
    }

    private var resolvedLocale: AppLocale {
        model.locale == .automatic ? AppCopy.currentLocale() : model.locale
    }

    private var activeSessions: [AgentSession] {
        model.monitoredSessions
    }

    private var selectedSession: AgentSession? {
        if let current = model.selectedSession, activeSessions.contains(where: { $0.id == current.id }) {
            return current
        }
        return activeSessions.first
    }

    private var compactWidth: CGFloat {
        let baseWidth = model.layoutMode == .clean ? 304.0 : 372.0
        guard let screen = preferredScreen(), screen.vibeIslandHasPhysicalNotch else {
            return baseWidth
        }

        let notchWidth = screen.vibeIslandNotchSize.width
        let menuBarSafeWidth = model.layoutMode == .clean ? 360.0 : 420.0
        return max(baseWidth, notchWidth + 96, menuBarSafeWidth)
    }

    private var expandedWidth: CGFloat {
        920
    }

    private var expandedHeight: CGFloat {
        CGFloat(min(max(model.maxPanelHeight, 420), 720))
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            Group {
                if model.islandExpanded {
                    expandedIsland
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    compactIsland
                        .transition(.scale(scale: 0.98).combined(with: .opacity))
                }
            }
            .onHover(perform: handleHover(_:))
        }
        .frame(
            width: model.islandExpanded ? expandedWidth : compactWidth,
            height: model.islandExpanded ? expandedHeight : compactHeight,
            alignment: .top
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: model.islandExpanded)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: model.selectedSessionID)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: model.dashboardMode)
        .onChange(of: model.selectedSessionID) { _, _ in
            inlineResponseText = ""
        }
    }

    private var compactIsland: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                pixelGlyph
                if activeSessions.count > 1 {
                    pixelGlyph
                        .opacity(0.92)
                }
                if compactShowsDetail, let session = selectedSession {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(statusLabel(session.status))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(statusColor(session.status))
                    }
                }
            }

            Spacer(minLength: 12)

            if let usage = model.currentUsageValue, model.layoutMode == .detailed {
                Text(usage)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .lineLimit(1)
            }

            Text(model.islandSessionCountText)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .frame(width: compactWidth, height: compactHeight)
        .background(
            NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
                .fill(Color.black.opacity(0.985))
                .overlay(
                    NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
                        .stroke(Color.white.opacity(0.02), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.30), radius: 12, y: 4)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.985))
                .frame(height: 2)
                .padding(.horizontal, 6)
        }
        .clipShape(NotchShape(topCornerRadius: 6, bottomCornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture {
            model.expandIsland()
        }
        .contextMenu {
            Button(copy(en: "Open Settings", zh: "打开设置")) {
                NotificationCenter.default.post(name: .vibeIslandOpenSettings, object: nil)
            }
            Button(copy(en: "Replay Onboarding", zh: "重新播放引导")) {
                NotificationCenter.default.post(name: .vibeIslandOpenOnboarding, object: nil)
            }
            Button(copy(en: "Hide", zh: "隐藏")) {
                NSApp.hide(nil)
            }
            Button(copy(en: "Quit Agent Island", zh: "退出 Agent Island")) {
                NSApp.terminate(nil)
            }
        }
    }

    private var expandedIsland: some View {
        VStack(spacing: 0) {
            expandedHeader

            Divider()
                .overlay(Color.white.opacity(0.06))

            if let session = selectedSession {
                HStack(alignment: .top, spacing: 18) {
                    sessionRail
                    conversationPanel(for: session)
                }
                .padding(18)
            } else {
                emptyState
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: expandedWidth, height: expandedHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.black.opacity(0.985))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: Color.black.opacity(0.46), radius: 30, y: 18)
    }

    private var expandedHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                pixelGlyph

                VStack(alignment: .leading, spacing: 2) {
                    Text("Agent Island")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(model.statusLine)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Image(systemName: model.runtimeDetectionState.dockerAvailable ? "shippingbox.fill" : "shippingbox")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(model.runtimeDetectionState.dockerAvailable ? Color(red: 0.25, green: 0.63, blue: 1.00) : Color.white.opacity(0.45))

                utilityButton(systemName: "arrow.clockwise") {
                    Task { await model.reloadLiveData() }
                }
                utilityButton(systemName: "gearshape.fill") {
                    NotificationCenter.default.post(name: .vibeIslandOpenSettings, object: nil)
                }
                utilityButton(systemName: "power") {
                    NSApp.terminate(nil)
                }
                utilityButton(systemName: "xmark") {
                    model.collapseIsland()
                }
            }
            .padding(.top, preferredScreen()?.vibeIslandHasPhysicalNotch == true ? 14 : 0)

            HStack(spacing: 8) {
                if model.sessions(for: .approve).isEmpty == false {
                    capsuleBadge("\(model.sessions(for: .approve).count) \(copy(en: "Approvals", zh: "审批"))")
                }
                if model.sessions(for: .ask).isEmpty == false {
                    capsuleBadge("\(model.sessions(for: .ask).count) \(copy(en: "Questions", zh: "提问"))")
                }
                if model.runtimeDetectionState.dockerAvailable {
                    capsuleBadge(copy(en: "Docker Ready", zh: "Docker 就绪"))
                }
                Spacer(minLength: 0)
            }
            .padding(.top, preferredScreen()?.vibeIslandHasPhysicalNotch == true ? 4 : 0)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var modeContextSection: some View {
        EmptyView()
    }

    private var sessionRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(copy(en: "Sessions", zh: "会话"))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(activeSessions.prefix(10)) { session in
                        sessionRailRow(session)
                    }
                }
            }
        }
        .frame(width: 278)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func sessionRailRow(_ session: AgentSession) -> some View {
        let isSelected = selectedSession?.id == session.id
        return Button {
            model.select(session)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(statusColor(session.status))
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 5) {
                    Text(session.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(primaryDescription(for: session))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        capsuleBadge(session.source.displayName)
                        if session.status.needsAttention {
                            capsuleBadge(statusLabel(session.status))
                        }
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? raisedSurfaceFill : surfaceFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.18) : surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func conversationPanel(for session: AgentSession) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                sessionSummaryCard(for: session)

                if let approval = session.approvalPayload {
                    approvalCard(approval, session: session)
                }

                if let question = session.questionPayload {
                    questionStrip(question, session: session)
                }

                if session.status == .waitingForInput || session.status == .waitingForApproval {
                    composerCard(for: session)
                }

                if model.selectedSessionHistory.isEmpty == false {
                    conversationHistorySection
                }

                let visibleTasks = model.visibleTasks(for: session)
                if visibleTasks.isEmpty == false {
                    tasksCard(tasks: visibleTasks)
                }

                if session.timeline.isEmpty == false {
                    timelineCard(for: session)
                }

                if model.showAgentDetail {
                    detailStrip(for: session)
                }

                if let diagnosticsMessage = model.diagnosticsMessage, diagnosticsMessage.isEmpty == false {
                    diagnosticsCard(message: diagnosticsMessage)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sessionSummaryCard(for session: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Circle()
                    .fill(statusColor(session.status))
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text(session.title)
                        .font(.system(size: max(22, model.contentFontSize + 8), weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(sessionPreviewText(primaryDescription(for: session), limit: 260))
                        .font(.system(size: model.contentFontSize + 1, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(3)

                    HStack(spacing: 8) {
                        capsuleBadge(session.source.displayName)
                        capsuleBadge(statusLabel(session.status))
                        if let agentRole = session.agentRole, model.showAgentDetail {
                            capsuleBadge(agentRole.capitalized)
                        }
                        if let usage = model.currentUsageValue {
                            capsuleBadge(usage)
                        }
                    }
                }

                Spacer(minLength: 16)

                Text(relativeTime(session.lastUpdated))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.44))
            }

            actionStrip(for: session)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        )
    }

    private func composerCard(for session: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(copy(en: "Reply Inline", zh: "直接回复"))
            HStack(spacing: 10) {
                TextField(
                    copy(en: "Type an answer or approval note…", zh: "输入回答或审批说明…"),
                    text: $inlineResponseText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(raisedSurfaceFill)
                )

                panelAction(
                    title: copy(en: "Send", zh: "发送"),
                    fill: Color.white.opacity(inlineResponseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.16 : 0.92),
                    foreground: inlineResponseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.36) : .black
                ) {
                    submitInlineResponse(for: session)
                }
                .disabled(inlineResponseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text(copy(
                en: "Supported agents receive this reply directly through the live socket bridge or CLI resume path.",
                zh: "正式支持的 Agent 会通过实时 socket bridge 或 CLI 恢复路径直接收到这条回复。"
            ))
            .font(.system(size: model.contentFontSize - 1, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.54))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        )
    }

    private var conversationHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(copy(en: "Conversation", zh: "会话"))

            VStack(spacing: 10) {
                ForEach(model.selectedSessionHistory.suffix(40)) { item in
                    conversationRow(item)
                }
            }
        }
    }

    private func conversationRow(_ item: AgentHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                capsuleBadge(historyTitle(for: item.kind))
                Text(relativeTime(item.timestamp))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.36))
            }

            Text(item.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if let body = item.body, body.isEmpty == false {
                conversationBody(body, kind: item.kind)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func conversationBody(_ body: String, kind: AgentHistoryItemKind) -> some View {
        if kind == .markdown, let attributed = try? AttributedString(markdown: body) {
            Text(attributed)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
                .textSelection(.enabled)
        } else {
            Text(body)
                .font(
                    kind == .tool
                    ? .system(size: 12, weight: .medium, design: .monospaced)
                    : .system(size: 12, weight: .medium, design: .rounded)
                )
                .foregroundStyle(Color.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private func submitInlineResponse(for session: AgentSession) {
        let response = inlineResponseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard response.isEmpty == false else { return }
        model.select(session)
        model.submitSelectedResponse(response)
        inlineResponseText = ""
    }

    private func sessionCard(for session: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Circle()
                    .fill(statusColor(session.status))
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text(session.title)
                        .font(.system(size: max(18, model.contentFontSize + 5), weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .truncationMode(.tail)

                    Text(sessionPreviewText(primaryDescription(for: session), limit: 240))
                        .font(.system(size: model.contentFontSize + 1, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(4)
                        .truncationMode(.tail)

                    HStack(spacing: 8) {
                        capsuleBadge(session.source.displayName)
                        capsuleBadge(statusLabel(session.status))
                        if let agentRole = session.agentRole, model.showAgentDetail {
                            capsuleBadge(agentRole.capitalized)
                        }
                        if let usage = model.currentUsageValue {
                            capsuleBadge(usage)
                        }
                    }
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(relativeTime(session.lastUpdated))
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.52))
                    if let terminalSessionId = session.terminalSessionId {
                        Text(model.terminalLabel(for: session))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(terminalSessionId.isEmpty ? Color.white.opacity(0.32) : Color.white.opacity(0.72))
                    }
                }
            }

            actionStrip(for: session)

            if let approval = session.approvalPayload {
                approvalCard(approval, session: session)
            }

            if let question = session.questionPayload, question.options.isEmpty == false {
                questionStrip(question, session: session)
            }

            let visibleTasks = model.visibleTasks(for: session)
            if visibleTasks.isEmpty == false {
                tasksCard(tasks: visibleTasks)
            }

            if session.timeline.isEmpty == false {
                timelineCard(for: session)
                    .frame(maxHeight: CGFloat(max(model.completionHeight, 120)))
            }

            if model.showAgentDetail {
                detailStrip(for: session)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        )
    }

    private func actionStrip(for session: AgentSession) -> some View {
        HStack(spacing: 10) {
            if session.terminalSessionId != nil {
                panelAction(title: copy(en: "Jump", zh: "跳转"), fill: Color(red: 0.23, green: 0.54, blue: 1.00)) {
                    model.select(session)
                    model.jumpToSelectedSession()
                }
            }

            if session.resumeCommand != nil {
                panelAction(title: copy(en: "Resume Session", zh: "恢复会话"), fill: Color.white.opacity(0.90), foreground: .black) {
                    model.select(session)
                    model.resumeSelectedSession()
                }
            }

            if session.originPath != nil {
                panelAction(title: copy(en: "Open Log", zh: "打开日志"), fill: Color.white.opacity(0.08)) {
                    model.select(session)
                    model.openSelectedSessionLog()
                }
                panelAction(title: copy(en: "Reveal Log", zh: "定位日志"), fill: Color.white.opacity(0.08)) {
                    model.select(session)
                    model.revealSelectedSessionLog()
                }
            }

            if session.workingDirectory != nil {
                panelAction(title: copy(en: "Open Folder", zh: "打开目录"), fill: Color.white.opacity(0.08)) {
                    model.select(session)
                    model.openSelectedWorkingDirectory()
                }
            }

            if session.resumeCommand != nil {
                panelAction(title: copy(en: "Copy Resume", zh: "复制恢复命令"), fill: Color.white.opacity(0.08)) {
                    model.select(session)
                    model.copyResumeCommand()
                }
            }
        }
    }

    private func approvalCard(_ approval: AgentApprovalPayload, session: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(approval.toolName)
                .font(.system(size: model.contentFontSize + 1, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(approval.summary)
                .font(.system(size: model.contentFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(4)
                .truncationMode(.tail)

            if approval.fileChanges.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(approval.fileChanges, id: \.path) { change in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(change.path)
                                .font(.system(size: model.contentFontSize - 1, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(change.summary)
                                .font(.system(size: model.contentFontSize - 1, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.58))
                                .lineLimit(2)
                                .truncationMode(.tail)
                        }
                    }
                }
            }

            Text(copy(
                en: "The OSS build copies the selected approval choice back to your clipboard so you can answer it in the source CLI.",
                zh: "开源版会把你选中的审批答案复制到剪贴板里，方便你粘贴回原始 CLI。"
            ))
            .font(.system(size: model.contentFontSize - 1, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.54))

            HStack(spacing: 10) {
                ForEach(Array(approval.choices.prefix(3)), id: \.self) { choice in
                    panelAction(title: actionCopyTitle(choice), fill: Color.white.opacity(0.08)) {
                        model.select(session)
                        model.submitSelectedResponse(choice)
                    }
                }
            }
        }
    }

    private var monitorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(copy(en: "Live Overview", zh: "实时总览"))
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.74))

            HStack(spacing: 12) {
                summaryTile(title: copy(en: "Sessions", zh: "会话"), value: "\(model.monitoredSessions.count)")
                summaryTile(title: copy(en: "Needs Approval", zh: "待审批"), value: "\(model.sessions(for: .approve).count)")
                summaryTile(title: copy(en: "Needs Input", zh: "待回答"), value: "\(model.sessions(for: .ask).count)")
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(copy(en: "Conversation History", zh: "会话历史"))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(model.selectedSessionHistory.suffix(8)) { item in
                        historyRow(item)
                    }
                }
            }
            .frame(maxHeight: 240)
        }
    }

    private var approvalQueueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(copy(en: "Approval Queue", zh: "审批队列"))

            let sessions = model.sessions(for: .approve)
            if sessions.isEmpty {
                modeEmptyCard(
                    title: copy(en: "No approval requests right now.", zh: "当前没有待审批请求。"),
                    detail: copy(en: "Once a source CLI asks for approval, it will show up here with real choices.", zh: "只要来源 CLI 发出真实审批请求，就会在这里显示真实选项。")
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(sessions.prefix(6)) { session in
                        modeSessionRow(session: session) {
                            model.select(session)
                        } actions: {
                            miniAction(copy(en: "Approve", zh: "批准")) {
                                model.select(session)
                                model.approveSelectedSession()
                            }
                            miniAction(copy(en: "Deny", zh: "拒绝")) {
                                model.select(session)
                                model.denySelectedSession()
                            }
                            miniAction(copy(en: "Bypass", zh: "绕过")) {
                                model.select(session)
                                model.bypassSelectedSession()
                            }
                        }
                    }
                }
            }
        }
    }

    private var questionQueueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(copy(en: "Question Queue", zh: "提问队列"))

            let sessions = model.sessions(for: .ask)
            if sessions.isEmpty {
                modeEmptyCard(
                    title: copy(en: "No questions are waiting right now.", zh: "当前没有等待回答的问题。"),
                    detail: copy(en: "When Claude, Codex, or Gemini needs an answer, the latest options will appear here.", zh: "当 Claude、Codex 或 Gemini 需要你的回答时，最新选项会在这里出现。")
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(sessions.prefix(6)) { session in
                        modeSessionRow(session: session) {
                            model.select(session)
                        } actions: {
                            if let options = session.questionPayload?.options {
                                ForEach(Array(options.prefix(3)), id: \.id) { option in
                                    miniAction(option.title) {
                                        model.select(session)
                                        model.answerSelectedQuestion(option: option)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func questionStrip(_ question: AgentQuestionPayload, session: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.prompt)
                .font(.system(size: model.contentFontSize + 1, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(3)
                .truncationMode(.tail)

            Text(copy(
                en: "Choosing an option copies the exact answer back to your clipboard so you can paste it into the source CLI.",
                zh: "点选选项后，会把对应答案原样复制到你的剪贴板，方便你粘贴回原始 CLI。"
            ))
            .font(.system(size: model.contentFontSize - 1, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.54))

            HStack(spacing: 10) {
                ForEach(Array(question.options.prefix(3)), id: \.id) { option in
                    panelAction(title: actionCopyTitle(option.title), fill: Color.white.opacity(0.08)) {
                        model.select(session)
                        model.answerSelectedQuestion(option: option)
                    }
                }
            }
        }
    }

    private func tasksCard(tasks: [AgentTaskSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy(en: "Tasks", zh: "任务"))
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.74))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(tasks) { task in
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(task.isComplete ? Color(red: 0.43, green: 0.89, blue: 0.59) : Color.white.opacity(0.48))

                        Text(task.title)
                            .font(.system(size: model.contentFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        )
    }

    private func timelineCard(for session: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(session.timeline.suffix(6)) { entry in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(timelineColor(entry.kind))
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(.system(size: model.contentFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .truncationMode(.tail)
                        if let detail = entry.detail {
                            Text(sessionPreviewText(detail, limit: 220))
                                .font(.system(size: model.contentFontSize - 1, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.46))
                                .lineLimit(2)
                                .truncationMode(.tail)
                        }
                    }

                    Spacer(minLength: 12)

                    Text(relativeTime(entry.timestamp))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.34))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        )
    }

    private func detailStrip(for session: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let workingDirectory = session.workingDirectory {
                detailLine(title: copy(en: "Working Directory", zh: "工作目录"), value: workingDirectory)
            }
            if let originPath = session.originPath {
                detailLine(title: copy(en: "Local Log", zh: "本地日志"), value: originPath)
            }
            if let resumeCommand = session.resumeCommand {
                detailLine(title: copy(en: "Resume Command", zh: "恢复命令"), value: resumeCommand)
            }
        }
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.46))
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.76))
                .textSelection(.enabled)
        }
    }

    private var relatedSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(copy(en: "Other Sessions", zh: "其他会话"))
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.74))

            VStack(spacing: 10) {
                ForEach(activeSessions.filter { $0.id != selectedSession?.id }.prefix(4)) { session in
                    Button {
                        model.select(session)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(statusColor(session.status))
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(primaryDescription(for: session))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.56))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(relativeTime(session.lastUpdated))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.36))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(surfaceFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(surfaceStroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.74))
    }

    private func summaryTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.46))
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        )
    }

    private func modeEmptyCard(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.58))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        )
    }

    private func modeSessionRow<Actions: View>(
        session: AgentSession,
        select: @escaping () -> Void,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: select) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(statusColor(session.status))
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(primaryDescription(for: session))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.56))
                            .lineLimit(2)
                    }
                    Spacer()
                    Text(relativeTime(session.lastUpdated))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.36))
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                actions()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        )
    }

    private func miniAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(raisedSurfaceFill)
                )
        }
        .buttonStyle(.plain)
    }

    private func utilityButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.84))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(raisedSurfaceFill)
                )
        }
        .buttonStyle(.plain)
    }

    private func historyRow(_ item: AgentHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                capsuleBadge(historyTitle(for: item.kind))
                Text(relativeTime(item.timestamp))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.36))
            }

            Text(item.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .truncationMode(.tail)

            if let body = item.body, body.isEmpty == false {
                historyBody(body, kind: item.kind)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func historyBody(_ body: String, kind: AgentHistoryItemKind) -> some View {
        let preview = historyPreviewBody(body)
        if kind == .markdown, let attributed = try? AttributedString(markdown: body) {
            Text(attributed)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(3)
                .truncationMode(.tail)
        } else {
            Text(preview)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.58))
                .lineLimit(3)
                .truncationMode(.tail)
        }
    }

    private func historyPreviewBody(_ body: String) -> String {
        sessionPreviewText(body, limit: 220)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            pixelGlyph
                .scaleEffect(1.8)

            Text(copy(en: "No Live Sessions Yet", zh: "还没有实时会话"))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(copy(
                en: model.emptyStateMessage,
                zh: model.emptyStateMessage
            ))
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.64))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 560)

            HStack(spacing: 8) {
                Image(systemName: model.runtimeDetectionState.dockerAvailable ? "shippingbox.fill" : "shippingbox")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(model.runtimeDetectionState.dockerAvailable ? Color.blue : Color.white.opacity(0.5))
                Text(model.runtimeDetectionState.dockerAvailable ? copy(en: "Docker available", zh: "Docker 可用") : copy(en: "Docker unavailable", zh: "Docker 不可用"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.68))
            }

            if let diagnosticsMessage = model.diagnosticsMessage, diagnosticsMessage.isEmpty == false {
                Text(sessionPreviewText(diagnosticsMessage, limit: 220))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)
            }

            HStack(spacing: 10) {
                panelAction(title: copy(en: "Open Settings", zh: "打开设置"), fill: Color.white.opacity(0.92), foreground: .black) {
                    NotificationCenter.default.post(name: .vibeIslandOpenSettings, object: nil)
                }
                panelAction(title: copy(en: "Refresh", zh: "刷新"), fill: Color.white.opacity(0.08)) {
                    Task { await model.reloadLiveData() }
                }
                panelAction(title: copy(en: "Quit", zh: "退出"), fill: Color(red: 0.32, green: 0.12, blue: 0.12)) {
                    NSApp.terminate(nil)
                }
            }
            .frame(maxWidth: 520)
        }
    }

    private func diagnosticsCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy(en: "Diagnostics", zh: "诊断"))
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.56))
                .lineLimit(4)
                .truncationMode(.tail)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(surfaceStroke, lineWidth: 1)
        )
    }

    private func panelAction(title: String, fill: Color, foreground: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(fill)
                )
        }
        .buttonStyle(.plain)
    }

    private var pixelGlyph: some View {
        HStack(spacing: 2) {
            VStack(spacing: 2) {
                Color(red: 0.29, green: 0.53, blue: 1.00)
                Color(red: 0.25, green: 0.45, blue: 0.92)
            }
            VStack(spacing: 2) {
                Color(red: 0.47, green: 0.69, blue: 1.00)
                Color(red: 0.38, green: 0.59, blue: 0.98)
            }
            VStack(spacing: 2) {
                Color(red: 0.52, green: 0.75, blue: 1.00)
                Color(red: 0.43, green: 0.66, blue: 0.98)
            }
        }
        .frame(width: 16, height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var compactHeight: CGFloat {
        let baseHeight = model.layoutMode == .clean ? 40.0 : 46.0
        guard let screen = preferredScreen(), screen.vibeIslandHasPhysicalNotch else {
            return baseHeight
        }
        return max(32, min(baseHeight, screen.vibeIslandNotchSize.height))
    }

    private var compactShowsDetail: Bool {
        guard let screen = preferredScreen(), screen.vibeIslandHasPhysicalNotch else {
            return model.layoutMode == .detailed
        }
        return model.layoutMode == .detailed && screen.vibeIslandNotchSize.width >= 260
    }

    private func preferredScreen() -> NSScreen? {
        switch model.displayTarget {
        case .automatic, .builtIn:
            return NSScreen.screens.first { screen in
                let name = screen.localizedName.lowercased()
                return name.contains("built") || name.contains("内建") || name.contains("retina")
            } ?? NSScreen.main ?? NSScreen.screens.first
        case .main:
            return NSScreen.main ?? NSScreen.screens.first
        }
    }

    private func capsuleBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.78))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
    }

    private func statusLabel(_ status: AgentStatus) -> String {
        switch status {
        case .idle: copy(en: "Idle", zh: "空闲")
        case .thinking: copy(en: "Thinking", zh: "处理中")
        case .runningTool: copy(en: "Running Tool", zh: "执行工具")
        case .waitingForApproval: copy(en: "Needs Approval", zh: "等待审批")
        case .waitingForInput: copy(en: "Waiting For Input", zh: "等待输入")
        case .complete: copy(en: "Complete", zh: "已完成")
        case .compacting: copy(en: "Compacting", zh: "压缩中")
        case .error: copy(en: "Error", zh: "错误")
        case .interrupted: copy(en: "Interrupted", zh: "已中断")
        }
    }

    private func primaryDescription(for session: AgentSession) -> String {
        session.lastAssistantMessage
            ?? session.timeline.last?.title
            ?? copy(en: "No assistant output has been captured yet.", zh: "还没有捕获到助理输出。")
    }

    private func statusColor(_ status: AgentStatus) -> Color {
        switch status {
        case .idle:
            return Color.white.opacity(0.38)
        case .thinking, .compacting:
            return Color(red: 0.47, green: 0.72, blue: 1.00)
        case .runningTool:
            return Color(red: 0.42, green: 0.91, blue: 0.58)
        case .waitingForApproval:
            return Color(red: 0.98, green: 0.70, blue: 0.34)
        case .waitingForInput:
            return Color(red: 0.39, green: 0.81, blue: 0.98)
        case .complete:
            return Color(red: 0.43, green: 0.89, blue: 0.59)
        case .error, .interrupted:
            return Color(red: 0.97, green: 0.40, blue: 0.34)
        }
    }

    private func timelineColor(_ kind: AgentTimelineEntryKind) -> Color {
        switch kind {
        case .user:
            return Color(red: 0.46, green: 0.72, blue: 1.00)
        case .assistant:
            return Color.white
        case .tool:
            return Color(red: 0.43, green: 0.89, blue: 0.59)
        case .system:
            return Color(red: 0.98, green: 0.70, blue: 0.34)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = max(Int(Date().timeIntervalSince(date)), 0)
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3_600 { return "\(seconds / 60)m" }
        if seconds < 86_400 { return "\(seconds / 3_600)h" }
        return "\(seconds / 86_400)d"
    }

    private func actionCopyTitle(_ value: String) -> String {
        "\(copy(en: "Copy", zh: "复制")) \(value)"
    }

    private func historyTitle(for kind: AgentHistoryItemKind) -> String {
        switch kind {
        case .user:
            return copy(en: "User", zh: "用户")
        case .assistant:
            return copy(en: "Assistant", zh: "助手")
        case .tool:
            return copy(en: "Tool", zh: "工具")
        case .system:
            return copy(en: "System", zh: "系统")
        case .markdown:
            return copy(en: "Plan Review", zh: "计划审阅")
        }
    }

    private func historySurfaceFill(for kind: AgentHistoryItemKind) -> Color {
        switch kind {
        case .markdown:
            return Color(red: 0.10, green: 0.14, blue: 0.18)
        default:
            return surfaceFill
        }
    }

    private func historySurfaceStroke(for kind: AgentHistoryItemKind) -> Color {
        switch kind {
        case .markdown:
            return Color(red: 0.28, green: 0.68, blue: 1.00).opacity(0.24)
        default:
            return surfaceStroke
        }
    }

    private func sessionPreviewText(_ text: String, limit: Int) -> String {
        let compact = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard compact.count > limit else { return compact }
        return String(compact.prefix(limit - 1)) + "…"
    }

    private var surfaceFill: Color {
        Color(red: 0.13, green: 0.13, blue: 0.14)
    }

    private var raisedSurfaceFill: Color {
        Color(red: 0.18, green: 0.18, blue: 0.20)
    }

    private var surfaceStroke: Color {
        Color.white.opacity(0.10)
    }

    private func copy(en: String, zh: String) -> String {
        switch resolvedLocale {
        case .zhHans:
            return zh
        default:
            return en
        }
    }

    private func handleHover(_ hovering: Bool) {
        collapseTask?.cancel()
        guard model.autoCollapseOnLeave, model.islandExpanded else { return }
        guard hovering == false else { return }
        collapseTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard Task.isCancelled == false else { return }
            model.collapseIsland()
        }
    }
}
