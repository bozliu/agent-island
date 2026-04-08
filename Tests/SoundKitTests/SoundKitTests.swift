import Foundation
import SoundKit
import XCTest

final class SoundKitTests: XCTestCase {
    func testImportPackCopiesManifestIntoApplicationSupportLayout() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourcePack = tempRoot.appendingPathComponent("source-pack", isDirectory: true)
        try FileManager.default.createDirectory(at: sourcePack, withIntermediateDirectories: true)

        let manifest = """
        {
          "id": "custom-pack",
          "displayName": "Custom Pack"
        }
        """
        try manifest.write(to: sourcePack.appendingPathComponent("pack.json"), atomically: true, encoding: .utf8)
        try Data("wave".utf8).write(to: sourcePack.appendingPathComponent("task_complete.wav"))

        let imported = try SoundPackCatalog.importPack(from: sourcePack, homeDirectory: tempRoot)
        let packs = SoundPackCatalog.availablePacks(homeDirectory: tempRoot)

        XCTAssertEqual(imported.id, "custom-pack")
        XCTAssertTrue(packs.contains(where: { $0.id == "custom-pack" && $0.displayName == "Custom Pack" }))
    }

    func testNormalizationFallsBackToDefaultPackIDWhenSelectionMissing() {
        let packs = [
            SoundPack(
                id: SoundPackCatalog.defaultPackID,
                displayName: "Default 8-Bit",
                isBundled: true,
                baseURL: URL(fileURLWithPath: "/tmp/default-8bit", isDirectory: true)
            )
        ]

        XCTAssertEqual(
            SoundPackCatalog.normalizedSelection("missing-pack", availablePacks: packs),
            SoundPackCatalog.defaultPackID
        )
    }
}
