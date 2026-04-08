import AppKit

public enum AgentIslandScreenMetrics {
    public static func topUnsafeInset(
        safeAreaTop: CGFloat,
        visibleTopInset: CGFloat,
        auxiliaryTopInset: CGFloat?
    ) -> CGFloat {
        if let auxiliaryTopInset, auxiliaryTopInset > 0 {
            return auxiliaryTopInset
        }
        if visibleTopInset > 0 {
            return visibleTopInset
        }
        return max(safeAreaTop, 0)
    }

    public static func notchHeight(
        safeAreaTop: CGFloat,
        auxiliaryTopInset: CGFloat?
    ) -> CGFloat {
        if let auxiliaryTopInset, auxiliaryTopInset > 0 {
            return auxiliaryTopInset
        }
        return max(safeAreaTop, 0)
    }
}

// Adapted from farouqaldori/claude-island under Apache-2.0.
public extension NSScreen {
    var vibeIslandNotchSize: CGSize {
        let notchHeight = AgentIslandScreenMetrics.notchHeight(
            safeAreaTop: safeAreaInsets.top,
            auxiliaryTopInset: vibeIslandAuxiliaryTopInset
        )
        guard notchHeight > 0 else {
            return CGSize(width: 224, height: 38)
        }

        let fullWidth = frame.width
        let leftPadding = auxiliaryTopLeftArea?.width ?? 0
        let rightPadding = auxiliaryTopRightArea?.width ?? 0
        guard leftPadding > 0, rightPadding > 0 else {
            return CGSize(width: 180, height: notchHeight)
        }

        return CGSize(width: fullWidth - leftPadding - rightPadding + 4, height: notchHeight)
    }

    var vibeIslandHasPhysicalNotch: Bool {
        safeAreaInsets.top > 0
    }

    var vibeIslandVisibleTopInset: CGFloat {
        max(frame.maxY - visibleFrame.maxY, 0)
    }

    var vibeIslandAuxiliaryTopInset: CGFloat? {
        if #available(macOS 12.0, *) {
            let candidates = [
                auxiliaryTopLeftArea?.height,
                auxiliaryTopRightArea?.height,
            ]
            .compactMap { $0 }
            .filter { $0 > 0 }

            if let inset = candidates.max() {
                return inset
            }
        }

        return nil
    }

    var vibeIslandTopUnsafeInset: CGFloat {
        AgentIslandScreenMetrics.topUnsafeInset(
            safeAreaTop: safeAreaInsets.top,
            visibleTopInset: vibeIslandVisibleTopInset,
            auxiliaryTopInset: vibeIslandAuxiliaryTopInset
        )
    }

    var vibeIslandNotchBottomY: CGFloat {
        if #available(macOS 12.0, *) {
            let candidates = [
                auxiliaryTopLeftArea?.minY,
                auxiliaryTopRightArea?.minY,
            ]
            .compactMap { $0 }

            if let topBoundary = candidates.min() {
                return topBoundary
            }
        }

        return visibleFrame.maxY
    }

    var vibeIslandBuiltinDisplay: Bool {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return false
        }
        return CGDisplayIsBuiltin(screenNumber) != 0
    }

    static var vibeIslandBuiltin: NSScreen? {
        if let builtin = screens.first(where: \.vibeIslandBuiltinDisplay) {
            return builtin
        }
        return NSScreen.main
    }
}
