import Foundation

public struct AgentStatusPayload: Codable, Sendable {
    let agent_name: String
    let status: String
    let terminal_pid: Int?
    let task_id: String?
}

public class AgentTransportAdapter {
    public static func handleIncomingStatus(_ jsonString: String) {
        // Broadcast real state to AppModel instead of fake data
        NotificationCenter.default.post(name: Notification.Name("AgentStatusUpdated"), object: nil, userInfo: ["json": jsonString])
    }
}
