import AppKit
import Foundation

public enum SoundCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case sessionStart
    case taskAcknowledge
    case taskComplete
    case taskError
    case inputRequired
    case resourceLimit
    case userSpam
}

public struct SoundPack: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let displayName: String
    public let isBundled: Bool
    public let baseURL: URL

    public init(id: String, displayName: String, isBundled: Bool, baseURL: URL) {
        self.id = id
        self.displayName = displayName
        self.isBundled = isBundled
        self.baseURL = baseURL
    }
}

private struct SoundPackManifest: Codable {
    let id: String
    let displayName: String
}

public struct SoundSettings: Sendable, Hashable, Codable {
    public var isEnabled: Bool
    public var volume: Double
    public var selectedSoundPackID: String

    public init(isEnabled: Bool = true, volume: Double = 0.7, selectedSoundPackID: String = SoundPackCatalog.defaultPackID) {
        self.isEnabled = isEnabled
        self.volume = volume
        self.selectedSoundPackID = selectedSoundPackID
    }
}

public final class SoundEngine {
    private var settings: SoundSettings

    public init(settings: SoundSettings = SoundSettings()) {
        self.settings = settings
    }

    public func update(settings: SoundSettings) {
        self.settings = settings
    }

    public func play(_ category: SoundCategory) {
        guard settings.isEnabled else { return }

        if let soundURL = SoundPackCatalog.soundURL(for: category, selectedPackID: settings.selectedSoundPackID),
           let customSound = NSSound(contentsOf: soundURL, byReference: true) {
            customSound.volume = Float(settings.volume)
            customSound.play()
            return
        }

        NSSound.beep()
    }
}

public enum SoundPackCatalog {
    public static let defaultPackID = "default-8bit"

    private static let packDirectoryName = "SoundPacks"
    private static let manifestFileName = "pack.json"

    public static func packsDirectory(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Application Support/Agent Island", isDirectory: true)
            .appendingPathComponent(packDirectoryName, isDirectory: true)
    }

    @discardableResult
    public static func ensurePacksDirectory(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> URL {
        let directory = packsDirectory(fileManager: fileManager, homeDirectory: homeDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public static func availablePacks(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [SoundPack] {
        let bundled = bundledPacks(bundle: bundle, fileManager: fileManager)
        let imported = importedPacks(fileManager: fileManager, homeDirectory: homeDirectory)
        return (bundled + imported)
            .sorted { lhs, rhs in
                if lhs.isBundled != rhs.isBundled {
                    return lhs.isBundled && !rhs.isBundled
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    public static func normalizedSelection(_ packID: String, availablePacks: [SoundPack]) -> String {
        if availablePacks.contains(where: { $0.id == packID }) {
            return packID
        }
        return availablePacks.first(where: { $0.id == defaultPackID })?.id ?? defaultPackID
    }

    public static func soundURL(
        for category: SoundCategory,
        selectedPackID: String,
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL? {
        let packs = availablePacks(bundle: bundle, fileManager: fileManager, homeDirectory: homeDirectory)
        let selectedID = normalizedSelection(selectedPackID, availablePacks: packs)

        if let pack = packs.first(where: { $0.id == selectedID }),
           let url = resolvedSoundURL(for: category, in: pack, fileManager: fileManager) {
            return url
        }

        if let defaultPack = packs.first(where: { $0.id == defaultPackID }),
           let fallback = resolvedSoundURL(for: category, in: defaultPack, fileManager: fileManager) {
            return fallback
        }

        return nil
    }

    public static func importPack(
        from sourceURL: URL,
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> SoundPack {
        let manifest = try loadManifest(at: sourceURL.appendingPathComponent(manifestFileName))
        let destinationRoot = try ensurePacksDirectory(fileManager: fileManager, homeDirectory: homeDirectory)
        let sanitizedID = sanitizePackID(manifest.id)
        let destination = destinationRoot.appendingPathComponent(sanitizedID, isDirectory: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return SoundPack(id: sanitizedID, displayName: manifest.displayName, isBundled: false, baseURL: destination)
    }

    public static func bundledPackPreviewURL(bundle: Bundle = .main) -> URL? {
        bundle.resourceURL?.appendingPathComponent("Sounds/\(defaultPackID)", isDirectory: true)
    }

    private static func bundledPacks(bundle: Bundle, fileManager: FileManager) -> [SoundPack] {
        guard let soundsURL = bundle.resourceURL?.appendingPathComponent("Sounds", isDirectory: true),
              let entries = try? fileManager.contentsOfDirectory(at: soundsURL, includingPropertiesForKeys: nil)
        else {
            return []
        }

        return entries.compactMap { url in
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return nil
            }
            guard let manifest = try? loadManifest(at: url.appendingPathComponent(manifestFileName)) else {
                return nil
            }
            return SoundPack(id: manifest.id, displayName: manifest.displayName, isBundled: true, baseURL: url)
        }
    }

    private static func importedPacks(fileManager: FileManager, homeDirectory: URL) -> [SoundPack] {
        let directory = packsDirectory(fileManager: fileManager, homeDirectory: homeDirectory)
        guard let entries = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }

        return entries.compactMap { url in
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return nil
            }
            guard let manifest = try? loadManifest(at: url.appendingPathComponent(manifestFileName)) else {
                return nil
            }
            return SoundPack(id: manifest.id, displayName: manifest.displayName, isBundled: false, baseURL: url)
        }
    }

    private static func resolvedSoundURL(for category: SoundCategory, in pack: SoundPack, fileManager: FileManager) -> URL? {
        for fileName in fileNames(for: category) {
            let url = pack.baseURL.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private static func fileNames(for category: SoundCategory) -> [String] {
        let canonicalName: String
        switch category {
        case .sessionStart: canonicalName = "session_start"
        case .taskAcknowledge: canonicalName = "task_ack"
        case .taskComplete: canonicalName = "task_complete"
        case .taskError: canonicalName = "task_error"
        case .inputRequired: canonicalName = "input_required"
        case .resourceLimit: canonicalName = "resource_limit"
        case .userSpam: canonicalName = "user_spam"
        }

        return ["wav", "aiff", "mp3"].map { "\(canonicalName).\($0)" }
    }

    private static func loadManifest(at url: URL) throws -> SoundPackManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SoundPackManifest.self, from: data)
    }

    private static func sanitizePackID(_ rawID: String) -> String {
        let sanitized = rawID
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9-_]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return sanitized.isEmpty ? UUID().uuidString.lowercased() : sanitized
    }
}
