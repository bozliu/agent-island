import Foundation

public struct TelemetrySettings: Sendable, Hashable, Codable {
    public var isOptedIn: Bool

    public init(isOptedIn: Bool = false) {
        self.isOptedIn = isOptedIn
    }
}

public struct TelemetryEvent: Sendable, Hashable {
    public let name: String
    public let metadata: [String: String]

    public init(name: String, metadata: [String: String] = [:]) {
        self.name = name
        self.metadata = metadata
    }
}

public protocol TelemetryClient: Sendable {
    func record(_ event: TelemetryEvent)
}

public struct NoOpTelemetryClient: TelemetryClient {
    public init() {}
    public func record(_ event: TelemetryEvent) {}
}

public struct ConsoleTelemetryClient: TelemetryClient {
    public init() {}

    public func record(_ event: TelemetryEvent) {
        let metadata = event.metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        print("[telemetry] \(event.name) \(metadata)")
    }
}

public final class TelemetryController {
    private let defaults: UserDefaults
    private let key = "app.vibeisland.telemetry.optin"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func currentSettings() -> TelemetrySettings {
        TelemetrySettings(isOptedIn: defaults.bool(forKey: key))
    }

    public func update(_ settings: TelemetrySettings) {
        defaults.set(settings.isOptedIn, forKey: key)
    }
}
