import AppKit
import Foundation

let outputRoot = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        .appendingPathComponent("assets/hero", isDirectory: true)

let framesURL = outputRoot.appendingPathComponent("frames", isDirectory: true)
let posterURL = outputRoot.appendingPathComponent("agent-island-hero-poster.png")

try FileManager.default.createDirectory(at: framesURL, withIntermediateDirectories: true)

struct Scene {
    let id: String
    let accent: NSColor
    let eyebrow: String
    let title: String
    let subtitle: String
    let chips: [String]
    let rows: [(String, String)]
}

let scenes: [Scene] = [
    Scene(
        id: "01-monitor",
        accent: NSColor(calibratedRed: 0.37, green: 0.84, blue: 0.53, alpha: 1),
        eyebrow: "MONITOR",
        title: "Every agent. One glance.",
        subtitle: "Claude Code, Codex CLI, Gemini CLI, and OpenCode in one ambient layer.",
        chips: ["Claude Code", "Codex CLI", "Gemini CLI", "OpenCode"],
        rows: [
            ("fix auth bug", "Claude Code · iTerm2"),
            ("deploy-api", "Codex CLI · Terminal"),
            ("refine prompt", "Gemini CLI · Warp"),
        ]
    ),
    Scene(
        id: "02-approve",
        accent: NSColor(calibratedRed: 0.98, green: 0.66, blue: 0.29, alpha: 1),
        eyebrow: "APPROVE",
        title: "Approve without switching windows.",
        subtitle: "Permission requests surface in the island so you can allow or deny instantly.",
        chips: ["Allow", "Deny", "Always allow"],
        rows: [
            ("Edit src/auth/middleware.ts", "- jwt.verify(token);"),
            ("", "+ verify(token) // expiry validation"),
            ("Running tests", "8 passed"),
        ]
    ),
    Scene(
        id: "03-ask",
        accent: NSColor(calibratedRed: 0.33, green: 0.77, blue: 0.97, alpha: 1),
        eyebrow: "ASK",
        title: "Answer questions from the notch.",
        subtitle: "When an agent needs input, pick an option and keep moving.",
        chips: ["Production", "Staging", "Local only"],
        rows: [
            ("Which deployment target?", "Choose one reply and continue"),
            ("Question queue", "No terminal context-switching"),
            ("Inline responses", "Works with approval and ask flows"),
        ]
    ),
    Scene(
        id: "04-jump",
        accent: NSColor(calibratedRed: 0.42, green: 0.56, blue: 1.00, alpha: 1),
        eyebrow: "JUMP",
        title: "Jump back to the exact context.",
        subtitle: "Return to iTerm2, Terminal, Warp, tmux, or IDE terminals from the island.",
        chips: ["iTerm2", "Warp", "tmux", "Cursor"],
        rows: [
            ("webapp · add dark mode", "Jump target ready"),
            ("resume command", "Open log or folder fallback"),
            ("Terminal routing", "Fast attention recovery"),
        ]
    ),
]

func drawBackground(in bounds: NSRect) {
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.52, alpha: 1),
        NSColor(calibratedRed: 0.35, green: 0.47, blue: 0.86, alpha: 1),
        NSColor(calibratedRed: 0.93, green: 0.74, blue: 0.52, alpha: 1),
        NSColor(calibratedRed: 0.50, green: 0.39, blue: 0.76, alpha: 1),
    ])!
    gradient.draw(in: bounds, angle: 32)

    for (x, width, rotation, alpha) in [
        (bounds.width * 0.58, bounds.width * 0.20, 22.0, 0.32),
        (bounds.width * 0.64, bounds.width * 0.26, 34.0, 0.26),
        (bounds.width * 0.18, bounds.width * 0.28, -34.0, 0.24),
    ] as [(CGFloat, CGFloat, Double, CGFloat)] {
        let rect = NSRect(x: x, y: -bounds.height * 0.10, width: width, height: bounds.height * 1.45)
        let path = NSBezierPath(roundedRect: rect, xRadius: width * 0.22, yRadius: width * 0.22)
        var transform = AffineTransform()
        transform.translate(x: rect.midX, y: rect.midY)
        transform.rotate(byDegrees: rotation)
        transform.translate(x: -rect.midX, y: -rect.midY)
        path.transform(using: transform)
        NSGraphicsContext.current?.saveGraphicsState()
        path.addClip()
        NSColor.white.withAlphaComponent(alpha).setFill()
        path.fill()
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    let vignette = NSGradient(colors: [
        NSColor.black.withAlphaComponent(0.32),
        NSColor.black.withAlphaComponent(0.08),
        NSColor.black.withAlphaComponent(0.36),
    ])!
    vignette.draw(in: bounds, relativeCenterPosition: .zero)
}

func chip(_ text: String, x: CGFloat, y: CGFloat, accent: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .bold),
        .foregroundColor: NSColor.white.withAlphaComponent(0.82),
    ]
    let string = NSString(string: text)
    let size = string.size(withAttributes: attrs)
    let rect = NSRect(x: x, y: y, width: size.width + 28, height: 34)
    let path = NSBezierPath(roundedRect: rect, xRadius: 17, yRadius: 17)
    accent.withAlphaComponent(0.16).setFill()
    path.fill()
    string.draw(at: NSPoint(x: rect.minX + 14, y: rect.minY + 8), withAttributes: attrs)
}

func render(scene: Scene, size: NSSize) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()

    let bounds = NSRect(origin: .zero, size: size)
    drawBackground(in: bounds)

    let islandRect = NSRect(x: size.width * 0.27, y: size.height * 0.77, width: size.width * 0.46, height: 108)
    let islandPath = NSBezierPath(roundedRect: islandRect, xRadius: 28, yRadius: 28)
    let islandGradient = NSGradient(colors: [
        NSColor(calibratedWhite: 0.03, alpha: 0.98),
        NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.11, alpha: 0.98),
    ])!
    islandGradient.draw(in: islandPath, angle: 270)
    NSColor.white.withAlphaComponent(0.10).setStroke()
    islandPath.lineWidth = 1.5
    islandPath.stroke()

    let iconRect = NSRect(x: islandRect.minX + 22, y: islandRect.midY - 12, width: 24, height: 24)
    let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: 7, yRadius: 7)
    scene.accent.setFill()
    iconPath.fill()

    let eyebrowAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .bold),
        .foregroundColor: scene.accent,
    ]
    NSString(string: scene.eyebrow).draw(at: NSPoint(x: islandRect.minX + 58, y: islandRect.maxY - 34), withAttributes: eyebrowAttrs)

    let rowTitleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 22, weight: .heavy),
        .foregroundColor: NSColor.white,
    ]
    let rowDetailAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 14, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.62),
    ]

    for (index, row) in scene.rows.enumerated() {
        let y = islandRect.maxY - 62 - CGFloat(index) * 24
        NSString(string: row.0).draw(at: NSPoint(x: islandRect.minX + 58, y: y), withAttributes: rowTitleAttrs)
        NSString(string: row.1).draw(at: NSPoint(x: islandRect.minX + 310, y: y + 2), withAttributes: rowDetailAttrs)
    }

    let contentRect = NSRect(x: size.width * 0.18, y: size.height * 0.25, width: size.width * 0.64, height: size.height * 0.32)
    let contentPath = NSBezierPath(roundedRect: contentRect, xRadius: 26, yRadius: 26)
    NSColor.black.withAlphaComponent(0.42).setFill()
    contentPath.fill()
    NSColor.white.withAlphaComponent(0.08).setStroke()
    contentPath.lineWidth = 1
    contentPath.stroke()

    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 34, weight: .black),
        .foregroundColor: NSColor.white,
    ]
    let subtitleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 19, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.76),
    ]

    NSString(string: scene.title).draw(
        in: NSRect(x: contentRect.minX + 36, y: contentRect.maxY - 90, width: contentRect.width - 72, height: 46),
        withAttributes: titleAttrs
    )
    NSString(string: scene.subtitle).draw(
        in: NSRect(x: contentRect.minX + 36, y: contentRect.maxY - 136, width: contentRect.width - 72, height: 58),
        withAttributes: subtitleAttrs
    )

    var chipX = contentRect.minX + 36
    for text in scene.chips {
        chip(text, x: chipX, y: contentRect.minY + 34, accent: scene.accent)
        chipX += CGFloat((text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 18, weight: .bold)]).width) + 46
    }

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AgentIsland.Hero", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
    }
    try png.write(to: url)
}

let size = NSSize(width: 1440, height: 900)
for scene in scenes {
    try writePNG(render(scene: scene, size: size), to: framesURL.appendingPathComponent("\(scene.id).png"))
}
try writePNG(render(scene: scenes[0], size: size), to: posterURL)

print("Generated hero frames in \(framesURL.path)")
