import AgentCore
import Foundation
import IDEBridge

@main
struct AgentIslandBridgeCLI {
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let command = try parse(arguments)
        let output = try BridgeCommandDispatcher.run(command)
        print(output)
    }

    private static func parse(_ arguments: [String]) throws -> BridgeCommand {
        guard let first = arguments.first else {
            return .inspect
        }

        if first == "--source" {
            guard let raw = arguments.dropFirst().first, let source = AgentSource(rawValue: raw) else {
                throw NSError(domain: "AgentIsland.Bridge", code: 64, userInfo: [
                    NSLocalizedDescriptionKey: "Usage: agent-island-bridge --source <claude|codex|gemini|openclaw|cursor|copilot|droid|qoder|codebuddy>"
                ])
            }
            return .captureEvent(source)
        }

        switch first {
        case "inspect":
            return .inspect
        case "inspect-live":
            return .inspectLive
        case "list-sources":
            return .listSources
        case "install-ide-bridge":
            guard let raw = arguments.dropFirst().first, let ide = IDEKind(rawValue: raw) else {
                throw NSError(domain: "AgentIsland.Bridge", code: 64, userInfo: [
                    NSLocalizedDescriptionKey: "Usage: agent-island-bridge install-ide-bridge <vscode|cursor>"
                ])
            }
            return .installIDEBridge(ide)
        case "emit-demo-event":
            guard let raw = arguments.dropFirst().first, let source = AgentSource(rawValue: raw) else {
                throw NSError(domain: "AgentIsland.Bridge", code: 64, userInfo: [
                    NSLocalizedDescriptionKey: "Usage: agent-island-bridge emit-demo-event <source>"
                ])
            }
            return .emitDemoEvent(source)
        default:
            throw NSError(domain: "AgentIsland.Bridge", code: 64, userInfo: [
                NSLocalizedDescriptionKey: "Unknown command: \(first)"
            ])
        }
    }
}
