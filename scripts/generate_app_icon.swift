import AppKit
import Foundation

let outputRoot = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        .appendingPathComponent("App/BundleResources", isDirectory: true)

let iconsetURL = outputRoot.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = outputRoot.appendingPathComponent("AppIcon.icns")
let extensionIconURL = outputRoot.appendingPathComponent("extension-icon.png")
let cursorIconURL = outputRoot.appendingPathComponent("cursor-pixel.png")
let onboardingWallpaperURL = outputRoot.appendingPathComponent("onboarding-wallpaper.jpg")

let fileManager = FileManager.default
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: outputRoot, withIntermediateDirectories: true)

func makeImage(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.24
    let outerPath = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
    outerPath.addClip()

    let backdropGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.03, green: 0.07, blue: 0.16, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.23, blue: 0.55, alpha: 1),
        NSColor(calibratedRed: 0.09, green: 0.69, blue: 0.86, alpha: 1),
    ])!
    backdropGradient.draw(in: bounds, angle: 38)

    NSColor.black.withAlphaComponent(0.16).setStroke()
    outerPath.lineWidth = max(1, size * 0.01)
    outerPath.stroke()

    NSColor(calibratedRed: 0.99, green: 0.49, blue: 0.36, alpha: 0.22).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.52, y: size * 0.56, width: size * 0.38, height: size * 0.32)).fill()
    NSColor(calibratedRed: 0.33, green: 0.82, blue: 1.00, alpha: 0.18).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.10, y: size * 0.18, width: size * 0.54, height: size * 0.42)).fill()

    let islandRect = NSRect(x: size * 0.14, y: size * 0.58, width: size * 0.72, height: size * 0.22)
    let islandPath = NSBezierPath(roundedRect: islandRect, xRadius: size * 0.10, yRadius: size * 0.10)
    let islandGradient = NSGradient(colors: [
        NSColor(calibratedWhite: 0.02, alpha: 1),
        NSColor(calibratedRed: 0.06, green: 0.09, blue: 0.13, alpha: 1),
    ])!
    islandGradient.draw(in: islandPath, angle: 270)
    NSColor.white.withAlphaComponent(0.14).setStroke()
    islandPath.lineWidth = max(1, size * 0.01)
    islandPath.stroke()

    let auroraRect = NSRect(x: size * 0.22, y: size * 0.54, width: size * 0.46, height: size * 0.032)
    let auroraPath = NSBezierPath(roundedRect: auroraRect, xRadius: size * 0.02, yRadius: size * 0.02)
    let auroraGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.23, green: 0.87, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.45, green: 1.00, blue: 0.78, alpha: 1),
    ])!
    auroraGradient.draw(in: auroraPath, angle: 0)

    let pulseBars: [(CGFloat, CGFloat, NSColor)] = [
        (islandRect.minX + size * 0.10, size * 0.060, NSColor(calibratedRed: 0.40, green: 0.87, blue: 1.00, alpha: 1)),
        (islandRect.minX + size * 0.17, size * 0.072, NSColor(calibratedRed: 0.64, green: 0.94, blue: 1.00, alpha: 1)),
        (islandRect.minX + size * 0.25, size * 0.054, NSColor.white),
    ]
    for (x, height, color) in pulseBars {
        color.setFill()
        NSBezierPath(roundedRect: NSRect(
            x: x,
            y: islandRect.midY - height / 2,
            width: size * 0.034,
            height: height
        ), xRadius: size * 0.017, yRadius: size * 0.017).fill()
    }

    let pulseDotRect = NSRect(
        x: islandRect.maxX - size * 0.13,
        y: islandRect.midY - size * 0.046,
        width: size * 0.092,
        height: size * 0.092
    )
    let pulseDot = NSBezierPath(ovalIn: pulseDotRect)
    NSColor(calibratedRed: 1.00, green: 0.61, blue: 0.34, alpha: 1).setFill()
    pulseDot.fill()
    NSColor.white.withAlphaComponent(0.34).setStroke()
    pulseDot.lineWidth = max(1, size * 0.008)
    pulseDot.stroke()

    NSColor.white.withAlphaComponent(0.82).setFill()
    NSBezierPath(ovalIn: NSRect(
        x: pulseDotRect.minX + size * 0.018,
        y: pulseDotRect.maxY - size * 0.040,
        width: size * 0.022,
        height: size * 0.022
    ))
    .fill()

    let reflections: [(Int, CGFloat, CGFloat)] = [(0, 0.52, 0.24), (1, 0.38, 0.18), (2, 0.24, 0.12)]
    for (index, widthScale, alpha) in reflections {
        let width = size * widthScale
        let rect = NSRect(
            x: (size - width) / 2,
            y: size * (0.20 - CGFloat(index) * 0.055),
            width: width,
            height: size * 0.028
        )
        let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.02, yRadius: size * 0.02)
        NSColor.white.withAlphaComponent(alpha).setFill()
        path.fill()
    }

    image.unlockFocus()
    return image
}

func makeMenuBarImage(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let islandRect = NSRect(x: size * 0.08, y: size * 0.20, width: size * 0.84, height: size * 0.54)
    let islandPath = NSBezierPath(roundedRect: islandRect, xRadius: size * 0.22, yRadius: size * 0.22)
    let islandGradient = NSGradient(colors: [
        NSColor(calibratedWhite: 0.02, alpha: 1),
        NSColor(calibratedRed: 0.06, green: 0.09, blue: 0.13, alpha: 1),
    ])!
    islandGradient.draw(in: islandPath, angle: 270)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    islandPath.lineWidth = max(1, size * 0.03)
    islandPath.stroke()

    let signalRect = NSRect(x: islandRect.minX + size * 0.18, y: islandRect.midY - size * 0.05, width: size * 0.30, height: size * 0.10)
    let signalPath = NSBezierPath(roundedRect: signalRect, xRadius: size * 0.04, yRadius: size * 0.04)
    let signalGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.26, green: 0.86, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.58, green: 0.98, blue: 0.80, alpha: 1),
    ])!
    signalGradient.draw(in: signalPath, angle: 0)

    let bars: [(CGFloat, CGFloat, NSColor)] = [
        (islandRect.minX + size * 0.16, size * 0.14, NSColor(calibratedRed: 0.40, green: 0.87, blue: 1.00, alpha: 1)),
        (islandRect.minX + size * 0.23, size * 0.17, NSColor.white),
    ]
    for (x, height, color) in bars {
        color.setFill()
        NSBezierPath(roundedRect: NSRect(
            x: x,
            y: islandRect.midY - height / 2,
            width: size * 0.05,
            height: height
        ), xRadius: size * 0.025, yRadius: size * 0.025).fill()
    }

    NSColor(calibratedRed: 1.00, green: 0.61, blue: 0.34, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(
        x: islandRect.maxX - size * 0.16,
        y: islandRect.midY - size * 0.06,
        width: size * 0.12,
        height: size * 0.12
    )).fill()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AgentIsland.IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG."])
    }
    try png.write(to: url)
}

func writeJPEG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else {
        throw NSError(domain: "AgentIsland.IconGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JPEG."])
    }
    try jpeg.write(to: url)
}

func makeWallpaperImage(size: NSSize) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()

    let bounds = NSRect(origin: .zero, size: size)
    let baseGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.45, alpha: 1),
        NSColor(calibratedRed: 0.30, green: 0.42, blue: 0.82, alpha: 1),
        NSColor(calibratedRed: 0.92, green: 0.72, blue: 0.48, alpha: 1),
        NSColor(calibratedRed: 0.42, green: 0.32, blue: 0.72, alpha: 1),
    ])!
    baseGradient.draw(in: bounds, angle: 32)

    func drawBeam(x: CGFloat, width: CGFloat, rotation: CGFloat, color: NSColor) {
        let rect = NSRect(x: x, y: -size.height * 0.10, width: width, height: size.height * 1.45)
        let path = NSBezierPath(roundedRect: rect, xRadius: width * 0.28, yRadius: width * 0.28)
        var transform = AffineTransform()
        transform.translate(x: rect.midX, y: rect.midY)
        transform.rotate(byDegrees: rotation)
        transform.translate(x: -rect.midX, y: -rect.midY)
        path.transform(using: transform)

        NSGraphicsContext.current?.saveGraphicsState()
        path.addClip()
        let gradient = NSGradient(colors: [
            color.withAlphaComponent(0.74),
            color.withAlphaComponent(0.08),
        ])!
        gradient.draw(in: path, angle: 270)
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    drawBeam(x: size.width * 0.56, width: size.width * 0.22, rotation: 18, color: NSColor(calibratedRed: 0.98, green: 0.86, blue: 0.63, alpha: 1))
    drawBeam(x: size.width * 0.62, width: size.width * 0.26, rotation: 32, color: NSColor(calibratedRed: 0.96, green: 0.72, blue: 0.46, alpha: 1))
    drawBeam(x: size.width * 0.20, width: size.width * 0.30, rotation: -33, color: NSColor(calibratedRed: 0.34, green: 0.56, blue: 0.95, alpha: 1))
    drawBeam(x: size.width * 0.08, width: size.width * 0.24, rotation: -48, color: NSColor(calibratedRed: 0.19, green: 0.33, blue: 0.84, alpha: 1))

    let vignette = NSGradient(colors: [
        NSColor.black.withAlphaComponent(0.40),
        NSColor.black.withAlphaComponent(0.06),
        NSColor.black.withAlphaComponent(0.34),
    ])!
    vignette.draw(in: bounds, relativeCenterPosition: .zero)

    image.unlockFocus()
    return image
}

let entries: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in entries {
    try writePNG(makeImage(size: size), to: iconsetURL.appendingPathComponent(name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    throw NSError(domain: "AgentIsland.IconGenerator", code: Int(iconutil.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed."])
}

try writePNG(makeMenuBarImage(size: 256), to: extensionIconURL)
try writePNG(makeImage(size: 128), to: cursorIconURL)
try writeJPEG(makeWallpaperImage(size: NSSize(width: 2560, height: 1600)), to: onboardingWallpaperURL)

try? fileManager.removeItem(at: iconsetURL)
print("Generated icon assets in \(outputRoot.path)")
