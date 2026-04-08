import Foundation

public enum AppLocale: String, Codable, CaseIterable, Sendable, Hashable {
    case automatic
    case en
    case zhHans = "zh-Hans"
    case ja
    case ko
}

public enum CopyKey: String, CaseIterable, Sendable {
    case appTitle
    case allAgentsOneIsland
    case needsAttention
    case waitingForInput
    case waitingForApproval
    case runningTool
    case completed
    case jumpToTerminal
    case openLatestRelease
    case diagnostics
    case noSessions
    case settings
    case soundEnabled
    case smartSuppression
    case showCompletedTasks
}

public enum AppCopy {
    public static func text(_ key: CopyKey, locale: AppLocale) -> String {
        let resolved = locale == .automatic ? currentLocale() : locale
        return dictionary[resolved]?[key] ?? dictionary[.en]?[key] ?? key.rawValue
    }

    public static func currentLocale() -> AppLocale {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        switch code {
        case "zh":
            return .zhHans
        case "ja":
            return .ja
        case "ko":
            return .ko
        default:
            return .en
        }
    }

    private static let dictionary: [AppLocale: [CopyKey: String]] = [
        .en: [
            .appTitle: "Agent Island",
            .allAgentsOneIsland: "All your agents, one island.",
            .needsAttention: "Needs attention",
            .waitingForInput: "Waiting for input",
            .waitingForApproval: "Needs approval",
            .runningTool: "Running tool",
            .completed: "Completed",
            .jumpToTerminal: "Jump to Terminal",
            .openLatestRelease: "Open Latest Release",
            .diagnostics: "Diagnostics",
            .noSessions: "The island awaits. Open a supported live CLI session to populate it.",
            .settings: "Settings",
            .soundEnabled: "Enable sound effects",
            .smartSuppression: "Smart suppression",
            .showCompletedTasks: "Show completed tasks",
        ],
        .zhHans: [
            .appTitle: "Agent Island",
            .allAgentsOneIsland: "所有 Agent，共居一岛。",
            .needsAttention: "需要关注",
            .waitingForInput: "等待输入",
            .waitingForApproval: "等待审批",
            .runningTool: "执行工具",
            .completed: "已完成",
            .jumpToTerminal: "跳转到终端",
            .openLatestRelease: "打开最新版本",
            .diagnostics: "诊断信息",
            .noSessions: "岛屿等待中。先打开受支持的实时 CLI 会话，这里才会出现内容。",
            .settings: "设置",
            .soundEnabled: "启用音效",
            .smartSuppression: "智能抑制",
            .showCompletedTasks: "显示已完成任务",
        ],
        .ja: [
            .appTitle: "Agent Island",
            .allAgentsOneIsland: "すべてのエージェントを、ひとつの島に。",
            .needsAttention: "要対応",
            .waitingForInput: "入力待ち",
            .waitingForApproval: "承認待ち",
            .runningTool: "ツール実行中",
            .completed: "完了",
            .jumpToTerminal: "ターミナルへ移動",
            .openLatestRelease: "最新リリースを開く",
            .diagnostics: "診断",
            .noSessions: "ライブ対応 CLI セッションを開くと、ここに内容が表示されます。",
            .settings: "設定",
            .soundEnabled: "サウンドを有効化",
            .smartSuppression: "スマート抑制",
            .showCompletedTasks: "完了タスクを表示",
        ],
        .ko: [
            .appTitle: "Agent Island",
            .allAgentsOneIsland: "모든 에이전트를 하나의 섬으로.",
            .needsAttention: "주의 필요",
            .waitingForInput: "입력 대기",
            .waitingForApproval: "승인 필요",
            .runningTool: "도구 실행 중",
            .completed: "완료",
            .jumpToTerminal: "터미널로 이동",
            .openLatestRelease: "최신 릴리스 열기",
            .diagnostics: "진단",
            .noSessions: "지원되는 라이브 CLI 세션을 열면 여기에 내용이 표시됩니다.",
            .settings: "설정",
            .soundEnabled: "사운드 효과 활성화",
            .smartSuppression: "스마트 억제",
            .showCompletedTasks: "완료된 작업 표시",
        ],
    ]
}
