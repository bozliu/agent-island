import AgentCore
import IDEBridge
import Localization
import SoundKit
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case display
    case sound
    case labs
    case about

    var id: String { rawValue }
}

public struct SettingsWindowView: View {
    @ObservedObject private var model: AppModel
    @State private var selectedSection: SettingsSection = .general

    public init(model: AppModel) {
        self.model = model
    }

    private var resolvedLocale: AppLocale {
        model.locale == .automatic ? AppCopy.currentLocale() : model.locale
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(width: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    currentSection
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
            .background(Color.white)
        }
        .frame(minWidth: 980, minHeight: 720)
        .background(Color.white)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarGroup(title: copy(en: "System", zh: "系统"), sections: [.general, .display, .sound])
            sidebarGroup(title: copy(en: "Workspace", zh: "工作区"), sections: [.labs])
            sidebarGroup(title: "Agent Island", sections: [.about])

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(minWidth: 288, idealWidth: 288, maxWidth: 288, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.98, green: 0.98, blue: 0.99))
    }

    @ViewBuilder
    private var currentSection: some View {
        switch selectedSection {
        case .general:
            generalSection
        case .display:
            displaySection
        case .sound:
            soundSection
        case .labs:
            labsSection
        case .about:
            aboutSection
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageHeader(copy(en: "General", zh: "通用"))

            settingsCard(title: copy(en: "System", zh: "系统")) {
                toggleRow(copy(en: "Launch at Login", zh: "登录时打开"), isOn: $model.launchAtLoginEnabled)
                pickerRow(copy(en: "Display", zh: "显示器")) {
                    Picker("", selection: $model.displayTarget) {
                        Text(copy(en: "Auto", zh: "自动")).tag(DisplayTarget.automatic)
                        Text(copy(en: "Built-in", zh: "内置")).tag(DisplayTarget.builtIn)
                        Text(copy(en: "Main", zh: "主屏幕")).tag(DisplayTarget.main)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            settingsCard(title: copy(en: "Behaviour", zh: "行为")) {
                toggleRow(copy(en: "Auto-hide when no active sessions", zh: "无活跃会话时自动隐藏"), isOn: $model.autoHideWhenIdle)
                toggleRow(
                    copy(en: "Show Completed Tasks", zh: "显示已完成任务"),
                    subtitle: copy(en: "Keep finished tool steps visible in the island timeline.", zh: "在灵动岛时间线中保留已完成工具步骤。"),
                    isOn: $model.showCompletedTasks
                )
                toggleRow(
                    copy(en: "Show Usage", zh: "显示用量"),
                    subtitle: copy(
                        en: "Display API usage data in the notch panel header",
                        zh: "在刘海面板顶部显示 API 用量数据"
                    ),
                    isOn: $model.showUsage
                )
                toggleRow(copy(en: "Auto-collapse on mouse leave", zh: "鼠标离开时自动收起"), isOn: $model.autoCollapseOnLeave)
                toggleRow(
                    copy(en: "Filter Probe Sessions", zh: "过滤探测会话"),
                    subtitle: copy(en: "Hide smoke-test and health-check sessions from the main island.", zh: "把 smoke test 和 health check 这类探测会话从主岛里过滤掉。"),
                    isOn: $model.autoDetectProbeSessions
                )
                pickerRow(copy(en: "Display Value", zh: "显示数值")) {
                    Picker("", selection: $model.usageValueMode) {
                        Text(copy(en: "Used", zh: "已用量")).tag(UsageValueMode.used)
                        Text(copy(en: "Remaining", zh: "剩余量")).tag(UsageValueMode.remaining)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            settingsCard(title: copy(en: "Actions", zh: "动作")) {
                actionRow(
                    title: copy(en: "Replay onboarding", zh: "重新播放引导"),
                    subtitle: copy(en: "Open the first-run intro again.", zh: "再次打开首次启动引导。"),
                    buttonTitle: copy(en: "Open", zh: "打开")
                ) {
                    NotificationCenter.default.post(name: .vibeIslandOpenOnboarding, object: nil)
                }

                actionRow(
                    title: copy(en: "Export diagnostics", zh: "导出诊断"),
                    subtitle: copy(en: "Collect anonymized local debugging data.", zh: "导出脱敏诊断信息。"),
                    buttonTitle: copy(en: "Export", zh: "导出")
                ) {
                    Task { await model.exportDiagnostics() }
                }
            }
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageHeader(copy(en: "Display", zh: "显示"))

            VStack(alignment: .leading, spacing: 14) {
                Text(copy(en: "Notch", zh: "刘海"))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(red: 0.24, green: 0.18, blue: 0.56))
                    .frame(height: 174)
                    .overlay(alignment: .top) {
                        HStack(spacing: 10) {
                            HStack(spacing: 4) {
                                miniGlyph(color: Color(red: 0.21, green: 0.54, blue: 1.00))
                                miniGlyph(color: Color(red: 0.46, green: 0.89, blue: 0.56))
                            }
                            Spacer()
                            Text(model.showUsage ? model.islandSessionCountText : " ")
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .frame(width: 470, height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.black)
                        )
                        .offset(y: 18)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )

                HStack(spacing: 14) {
                    layoutOptionCard(
                        title: copy(en: "Clean", zh: "简洁"),
                        subtitle: copy(en: "More room for the menu bar", zh: "给菜单栏图标让路"),
                        badge: copy(en: "Focus", zh: "聚焦"),
                        selected: model.layoutMode == .clean
                    ) {
                        model.layoutMode = .clean
                    }

                    layoutOptionCard(
                        title: copy(en: "Detailed", zh: "详细"),
                        subtitle: copy(en: "Titles and state at a glance", zh: "会话标题和状态一目了然"),
                        badge: "\(model.monitoredSessions.count)",
                        selected: model.layoutMode == .detailed
                    ) {
                        model.layoutMode = .detailed
                    }
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(copy(en: "Panel", zh: "面板"))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                panelPreviewCard
            }

            settingsCard(title: copy(en: "Sizing", zh: "尺寸")) {
                sliderRow(
                    title: copy(en: "Content Font Size", zh: "内容字体大小"),
                    valueLabel: "\(Int(model.contentFontSize))pt \(copy(en: "(Default)", zh: "（默认）"))",
                    value: $model.contentFontSize,
                    range: 11...18
                )
                sliderRow(
                    title: copy(en: "Completion Card Height", zh: "完成卡片高度"),
                    valueLabel: "\(Int(model.completionHeight))pt · \(copy(en: "Default", zh: "默认"))",
                    value: $model.completionHeight,
                    range: 90...240
                )
                sliderRow(
                    title: copy(en: "Max Panel Height", zh: "最大面板高度"),
                    valueLabel: "\(Int(model.maxPanelHeight))pt · \(copy(en: "Default", zh: "默认"))",
                    value: $model.maxPanelHeight,
                    range: 420...860
                )
            }

            settingsCard(title: "Agents") {
                toggleRow(copy(en: "Show Agent Activity Detail", zh: "显示代理活动详情"), isOn: $model.showAgentDetail)
                if model.showAgentDetail {
                    Text(copy(
                        en: "When the source provides it, the island will show role, working directory, log path, and resume command directly from the live session.",
                        zh: "只要来源本身提供这些字段，灵动岛就会直接展示真实的角色、工作目录、日志路径和恢复命令。"
                    ))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                }
            }
        }
    }

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageHeader(copy(en: "Sound", zh: "声音"))

            settingsCard(title: copy(en: "Session", zh: "会话")) {
                toggleRow(copy(en: "Enable Sound Effects", zh: "启用音效"), isOn: Binding(
                    get: { model.soundSettings.isEnabled },
                    set: { newValue in
                        model.soundSettings = SoundSettings(
                            isEnabled: newValue,
                            volume: model.soundSettings.volume,
                            selectedSoundPackID: model.soundSettings.selectedSoundPackID
                        )
                    }
                ))
                sliderRow(
                    title: copy(en: "Volume", zh: "音量"),
                    valueLabel: "\(Int(model.soundSettings.volume * 100))%",
                    value: Binding(
                        get: { model.soundSettings.volume },
                        set: { newValue in
                            model.soundSettings = SoundSettings(
                                isEnabled: model.soundSettings.isEnabled,
                                volume: newValue,
                                selectedSoundPackID: model.soundSettings.selectedSoundPackID
                            )
                        }
                    ),
                    range: 0...1
                )
                pickerRow(copy(en: "Sound Pack", zh: "音色包")) {
                    Picker("", selection: Binding(
                        get: { model.soundSettings.selectedSoundPackID },
                        set: { newValue in
                            model.selectSoundPack(newValue)
                        }
                    )) {
                        ForEach(model.soundPacks) { pack in
                            Text(pack.displayName + (pack.isBundled ? copy(en: " · Default", zh: " · 默认") : ""))
                                .tag(pack.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            settingsCard(title: copy(en: "Sound Packs", zh: "音色包")) {
                infoRow(
                    label: copy(en: "Current", zh: "当前"),
                    value: model.selectedSoundPack?.displayName ?? "default-8bit"
                )
                actionRow(
                    title: copy(en: "Import Sound Pack", zh: "导入音色包"),
                    subtitle: copy(en: "Import a folder that contains pack.json and audio files named after the built-in categories.", zh: "导入一个包含 pack.json 和标准分类音频文件名的文件夹。"),
                    buttonTitle: copy(en: "Import", zh: "导入")
                ) {
                    model.importSoundPack()
                }
                actionRow(
                    title: copy(en: "Open SoundPacks Folder", zh: "打开音色包目录"),
                    subtitle: copy(en: "Open the Application Support folder where imported packs live.", zh: "打开存放用户导入音色包的 Application Support 目录。"),
                    buttonTitle: copy(en: "Open Folder", zh: "打开目录")
                ) {
                    model.openSoundPacksFolder()
                }
                actionRow(
                    title: copy(en: "Restore Default Pack", zh: "恢复默认音色包"),
                    subtitle: copy(en: "Switch back to the bundled default-8bit pack instantly.", zh: "立刻切回内置的 default-8bit 默认音色包。"),
                    buttonTitle: copy(en: "Restore", zh: "恢复")
                ) {
                    model.restoreDefaultSoundPack()
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(copy(en: "Categories", zh: "分类"))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))

                ForEach(SoundCategory.allCases, id: \.self) { category in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(soundTitle(category))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Text(soundDescription(category))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(copy(en: "Preview", zh: "试听")) {
                            model.previewSound(category)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(16)
                    .background(cardBackground)
                }
            }
        }
    }

    private var labsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageHeader(copy(en: "Integrations", zh: "集成"))

            settingsCard(title: copy(en: "Detected Sources", zh: "检测到的来源")) {
                Text(model.runtimeDetectionState.dockerMessage)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                HStack(spacing: 8) {
                    Image(systemName: model.runtimeDetectionState.dockerAvailable ? "shippingbox.fill" : "shippingbox")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(model.runtimeDetectionState.dockerAvailable ? .blue : .secondary)
                    Text(copy(en: "Docker Runtime", zh: "Docker 运行时"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text(model.runtimeDetectionState.dockerAvailable ? copy(en: "Available", zh: "可用") : copy(en: "Unavailable", zh: "不可用"))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(model.runtimeDetectionState.dockerAvailable ? .blue : .secondary)
                }
                .padding(.bottom, 10)

                Text(copy(
                    en: "Agent Island first checks what is available on this Mac. Then you decide which sources should be added to the island.",
                    zh: "Agent Island 会先检测这台 Mac 上有哪些来源，然后由你决定要把哪些来源加入灵动岛。"
                ))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

                actionRow(
                    title: copy(en: "Enable All Supported Sources", zh: "全部启用正式支持来源"),
                    subtitle: copy(en: "Turn on every first-class source that was found on this Mac in one step.", zh: "把这台机器上已检测到的正式支持来源一次性全部启用。"),
                    buttonTitle: copy(en: "Enable All", zh: "全部启用")
                ) {
                    model.enableAllDetectedSources()
                }

                actionRow(
                    title: copy(en: "Repair All Enabled Sources", zh: "修复所有已启用来源"),
                    subtitle: copy(en: "Run managed hook and bridge repair for every currently enabled source.", zh: "为当前所有已启用来源统一执行 hook 和 bridge 修复。"),
                    buttonTitle: copy(en: "Repair All", zh: "全部修复")
                ) {
                    Task { await model.repairAllEnabledSources() }
                }

                actionRow(
                    title: copy(en: "Rollback All Managed Hooks", zh: "回滚所有托管 Hook"),
                    subtitle: copy(en: "Remove managed hook configuration for every enabled source.", zh: "移除所有已启用来源的托管 hook 配置。"),
                    buttonTitle: copy(en: "Rollback All", zh: "全部回滚")
                ) {
                    Task { await model.rollbackAllManagedSources() }
                }

                ForEach(model.productSourceSelectionStates) { state in
                    sourceSelectionRow(state)
                }

                actionRow(
                    title: copy(en: "Rescan This Mac", zh: "重新检测这台机器"),
                    subtitle: copy(en: "Refresh the local source detection and reload active sessions.", zh: "重新检测本机来源，并刷新当前会话。"),
                    buttonTitle: copy(en: "Rescan", zh: "重新检测")
                ) {
                    Task {
                        await model.refreshSourceSelectionStates()
                        await model.reloadLiveData()
                    }
                }
            }

            settingsCard(title: "CLI Hooks") {
                ForEach(model.adapterSetupStates) { state in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(state.source.rawValue.uppercased())
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                            Spacer()
                            Text(hookStatus(state.status))
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(state.status == .unavailable ? .red : .secondary)
                        }
                        Text(state.message)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        if state.touchedPaths.isEmpty == false {
                            Text(state.touchedPaths.joined(separator: "\n"))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Button(copy(en: "Repair", zh: "修复")) {
                            Task { await model.repairHooks(for: state.source) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        Divider().opacity(0.5)
                    }
                }
            }

            settingsCard(title: copy(en: "IDE Extensions", zh: "IDE 扩展")) {
                ForEach(IDEBridgeInstaller.supportedExtensions, id: \.identifier) { descriptor in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(descriptor.displayName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text(descriptor.installHint)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Divider().opacity(0.5)
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageHeader(copy(en: "About", zh: "关于"))

            settingsCard(title: copy(en: "Build", zh: "构建")) {
                infoRow(label: copy(en: "Current Version", zh: "当前版本"), value: model.currentAppVersion)
                if let latestReleaseName = model.latestReleaseName {
                    infoRow(label: copy(en: "Latest Release", zh: "最新版本"), value: latestReleaseName)
                }
                switch model.updatePresentation {
                case .idle:
                    infoRow(label: copy(en: "State", zh: "状态"), value: copy(en: "Idle", zh: "空闲"))
                case .checking:
                    infoRow(label: copy(en: "State", zh: "状态"), value: copy(en: "Checking…", zh: "检查中…"))
                case .available(let name):
                    infoRow(label: copy(en: "Update", zh: "更新"), value: name)
                case .upToDate(let name):
                    infoRow(label: copy(en: "Update", zh: "更新"), value: name)
                case .failed(let message):
                    infoRow(label: copy(en: "Error", zh: "错误"), value: message)
                }

                Divider().opacity(0.5)
                    .padding(.vertical, 8)

                HStack(spacing: 10) {
                    Button(copy(en: "Check Updates", zh: "检查更新")) {
                        Task { await model.checkForUpdates() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button(copy(en: "GitHub Releases", zh: "GitHub Releases")) {
                        model.openLatestRelease()
                    }
                    .buttonStyle(.bordered)
                }
            }

            settingsCard(title: copy(en: "Diagnostics", zh: "诊断")) {
                if let diagnosticsMessage = model.diagnosticsMessage {
                    Text(diagnosticsMessage)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(copy(en: "No diagnostics yet.", zh: "暂无诊断信息。"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            settingsCard(title: copy(en: "Community", zh: "社区")) {
                HStack(spacing: 10) {
                    Button(copy(en: "GitHub Repository", zh: "GitHub 仓库")) {
                        model.openRepository()
                    }
                    .buttonStyle(.bordered)

                    Button(copy(en: "Report an Issue", zh: "报告问题")) {
                        model.openIssueTracker()
                    }
                    .buttonStyle(.bordered)
                }
                Text(copy(
                    en: "This build is distributed through the GitHub repository and GitHub Releases only. Export diagnostics before filing a bug upstream.",
                    zh: "这个版本只通过 GitHub 仓库和 GitHub Releases 分发。提交问题前，建议先导出诊断信息。"
                ))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            }
        }
    }

    private var panelPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let session = model.primarySession {
                HStack {
                    Text(session.title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(session.source.displayName)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Text(session.lastAssistantMessage ?? copy(en: "No assistant output captured yet.", zh: "还没有捕获到助理输出。"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(3)

                if let entry = session.timeline.last {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(copy(en: "Latest Timeline Entry", zh: "最新时间线"))
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.44))
                        Text(entry.title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        if let detail = entry.detail {
                            Text(detail)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.48))
                                .lineLimit(2)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                }
            } else {
                Text(copy(
                    en: "This preview is now driven by real sessions. Once a supported CLI is active, its latest title, message, and timeline entry will appear here.",
                    zh: "这里的预览已经改成真实会话驱动。只要支持的 CLI 正在运行，这里就会显示它的最新标题、消息和时间线。"
                ))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 18, y: 10)
    }

    private func sidebarGroup(title: String, sections: [SettingsSection]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.secondary)
                .padding(.leading, 10)
                .padding(.bottom, 6)

            ForEach(sections) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(sectionTint(section))
                            .frame(width: 30, height: 30)
                            .overlay {
                                Image(systemName: sectionIcon(section))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                        Text(sectionTitle(section))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedSection == section ? .white : Color.black.opacity(0.88))

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selectedSection == section ? Color.blue : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 24)
    }

    private func pageHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 26, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.black.opacity(0.92))
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .heavy, design: .rounded))

            VStack(spacing: 0) {
                content()
            }
            .padding(14)
            .background(cardBackground)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color(red: 0.98, green: 0.98, blue: 0.99))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }

    private func toggleRow(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    private func sourceSelectionRow(_ state: SourceSelectionState) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(sourceTitle(state.source))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    if state.source.supportLevel == .experimental {
                        Text(copy(en: "Experimental", zh: "实验性"))
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                    Text(state.isDetected ? copy(en: "Detected", zh: "已检测到") : copy(en: "Not Found", zh: "未检测到"))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(state.isDetected ? Color.green : Color.secondary)
                    if state.isInstalledOnHost {
                        Text(copy(en: "Installed", zh: "已安装"))
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.blue)
                    }
                    if state.isProcessRunning {
                        Text(copy(en: "Running", zh: "运行中"))
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                    if state.recentSessionCount > 0 {
                        Text("\(state.recentSessionCount)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                if let capabilities = model.capabilities(for: state.source) {
                    HStack(spacing: 6) {
                        capabilityBadge(copy(en: "Realtime", zh: "实时"), enabled: capabilities.supportsRealtimeUpdates)
                        capabilityBadge(copy(en: "Submit", zh: "提交"), enabled: capabilities.supportsDirectSubmit)
                        capabilityBadge(copy(en: "History", zh: "历史"), enabled: capabilities.supportsHistory)
                        capabilityBadge(copy(en: "Auto", zh: "自动"), enabled: capabilities.supportsAutoInstall)
                    }
                }

                Text(state.detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if state.recentSessionTitles.isEmpty == false {
                    Text(copy(en: "Recent 6 sessions", zh: "最近 6 个会话"))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(state.recentSessionTitles, id: \.self) { title in
                            Text("• \(title)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if state.touchedPaths.isEmpty == false {
                    Text(state.touchedPaths.joined(separator: "\n"))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button(copy(en: "Repair", zh: "修复")) {
                        Task { await model.repairHooks(for: state.source) }
                    }
                    .buttonStyle(.bordered)

                    Button(copy(en: "Rollback", zh: "回滚")) {
                        Task { await model.rollbackHooks(for: state.source) }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { state.isEnabled },
                set: { newValue in
                    model.setSourceEnabled(state.source, isEnabled: newValue)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .disabled(state.isDetected == false)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    private func pickerRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 18) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Spacer()
            content()
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    private func sliderRow(title: String, valueLabel: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .tint(Color.blue)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    private func actionRow(title: String, subtitle: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 18) {
            Text(label)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func layoutOptionCard(title: String, subtitle: String, badge: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 10) {
                HStack {
                    Circle()
                        .fill(Color.green.opacity(0.34))
                        .frame(width: 8, height: 8)
                    Spacer()
                    Text(badge)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Text(title)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.84))

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 148)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? Color.blue : Color.black.opacity(0.08), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func capabilityBadge(_ title: String, enabled: Bool) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(enabled ? Color.green : Color.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill((enabled ? Color.green : Color.black).opacity(0.08))
            )
    }

    private func miniGlyph(color: Color) -> some View {
        HStack(spacing: 2) {
            Rectangle().fill(color).frame(width: 6, height: 6)
            Rectangle().fill(color.opacity(0.82)).frame(width: 6, height: 6)
        }
    }

    private func diffLine(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(text.hasPrefix("+") ? Color.green : text.hasPrefix("-") ? Color.red : Color.white.opacity(0.82))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint)
    }

    private func sectionTitle(_ section: SettingsSection) -> String {
        switch section {
        case .general: return copy(en: "General", zh: "通用")
        case .display: return copy(en: "Display", zh: "显示")
        case .sound: return copy(en: "Sound", zh: "声音")
        case .labs: return copy(en: "Integrations", zh: "集成")
        case .about: return copy(en: "About", zh: "关于")
        }
    }

    private func sectionIcon(_ section: SettingsSection) -> String {
        switch section {
        case .general: return "gearshape.fill"
        case .display: return "textformat.size"
        case .sound: return "speaker.wave.2.fill"
        case .labs: return "puzzlepiece.extension.fill"
        case .about: return "info.circle.fill"
        }
    }

    private func sectionTint(_ section: SettingsSection) -> Color {
        switch section {
        case .general: return Color.gray.opacity(0.86)
        case .display: return Color.purple
        case .sound: return Color.green
        case .labs: return Color.orange
        case .about: return Color.blue
        }
    }

    private func soundTitle(_ category: SoundCategory) -> String {
        switch category {
        case .sessionStart: return copy(en: "Session Start", zh: "会话开始")
        case .taskAcknowledge: return copy(en: "Task Acknowledge", zh: "任务确认")
        case .taskComplete: return copy(en: "Task Complete", zh: "任务完成")
        case .taskError: return copy(en: "Task Error", zh: "任务错误")
        case .inputRequired: return copy(en: "Approval Needed", zh: "需要审批")
        case .resourceLimit: return copy(en: "Context Limit", zh: "上下文限制")
        case .userSpam: return copy(en: "Spam Detection", zh: "连续提交检测")
        }
    }

    private func soundDescription(_ category: SoundCategory) -> String {
        switch category {
        case .sessionStart:
            return copy(en: "New Claude, Codex, or Gemini session", zh: "新的 Claude / Codex / Gemini 会话")
        case .taskAcknowledge:
            return copy(en: "You submitted a prompt", zh: "你发送了一条消息")
        case .taskComplete:
            return copy(en: "AI finished its turn", zh: "AI 完成了本轮回复")
        case .taskError:
            return copy(en: "Tool failure or API error", zh: "工具失败或 API 错误")
        case .inputRequired:
            return copy(en: "Permission or question pending", zh: "等待权限审批或回答问题")
        case .resourceLimit:
            return copy(en: "Context window compacting", zh: "上下文窗口压缩中")
        case .userSpam:
            return copy(en: "3+ prompts in 10 seconds", zh: "10 秒内发送了 3+ 条消息")
        }
    }

    private func hookStatus(_ status: HookInstallationStatus) -> String {
        switch status {
        case .installed: return copy(en: "Installed", zh: "已安装")
        case .repaired: return copy(en: "Repaired", zh: "已修复")
        case .manual: return copy(en: "Manual", zh: "手动")
        case .unavailable: return copy(en: "Unavailable", zh: "不可用")
        }
    }

    private func sourceTitle(_ source: AgentSource) -> String {
        source.displayName
    }

    private func copy(en: String, zh: String) -> String {
        resolvedLocale == .zhHans ? zh : en
    }
}

private struct SubagentPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.72))
                Text("Subagents (2)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Explore (Search API endpoints)  8s")
                    .foregroundStyle(.white)
                Text("└ Grep: handleRequest")
                    .foregroundStyle(Color.white.opacity(0.46))
                Text("Explore (Read config files)  Done")
                    .foregroundStyle(Color.white.opacity(0.82))
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black)
        )
    }
}
