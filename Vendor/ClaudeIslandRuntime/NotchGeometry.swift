import CoreGraphics
import Foundation

// Adapted from farouqaldori/claude-island under Apache-2.0.
public struct NotchGeometry: Sendable {
    public let deviceNotchRect: CGRect
    public let screenRect: CGRect
    public let windowHeight: CGFloat

    public init(deviceNotchRect: CGRect, screenRect: CGRect, windowHeight: CGFloat) {
        self.deviceNotchRect = deviceNotchRect
        self.screenRect = screenRect
        self.windowHeight = windowHeight
    }

    public var notchScreenRect: CGRect {
        CGRect(
            x: screenRect.midX - deviceNotchRect.width / 2,
            y: screenRect.maxY - deviceNotchRect.height,
            width: deviceNotchRect.width,
            height: deviceNotchRect.height
        )
    }

    public func topCenteredRect(for size: CGSize, topPadding: CGFloat = 0) -> CGRect {
        CGRect(
            x: screenRect.midX - size.width / 2,
            y: screenRect.maxY - size.height - topPadding,
            width: size.width,
            height: size.height
        )
    }
}

public struct IslandAnchorMetrics: Sendable, Hashable {
    public let screenRect: CGRect
    public let visibleFrame: CGRect
    public let topUnsafeInset: CGFloat
    public let notchBottomY: CGFloat
    public let shellHeight: CGFloat

    public init(
        screenRect: CGRect,
        visibleFrame: CGRect,
        topUnsafeInset: CGFloat,
        notchBottomY: CGFloat,
        shellHeight: CGFloat
    ) {
        self.screenRect = screenRect
        self.visibleFrame = visibleFrame
        self.topUnsafeInset = topUnsafeInset
        self.notchBottomY = notchBottomY
        self.shellHeight = shellHeight
    }

    public var shellFrame: CGRect {
        CGRect(
            x: screenRect.minX,
            y: screenRect.maxY - shellHeight,
            width: screenRect.width,
            height: shellHeight
        )
    }

    public var localAnchorY: CGFloat {
        shellHeight - topUnsafeInset
    }

    public func contentRect(for size: CGSize) -> CGRect {
        contentRect(for: size, topInset: topUnsafeInset)
    }

    public func contentRect(for size: CGSize, topInset: CGFloat) -> CGRect {
        CGRect(
            x: (screenRect.width - size.width) / 2,
            y: shellHeight - topInset - size.height,
            width: size.width,
            height: size.height
        ).integral
    }
}
