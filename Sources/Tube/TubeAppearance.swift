import AppKit

enum TubeAppearance {
    static let dynamicWindowBackground = NSColor(name: NSColor.Name("TubeWindowBackground")) { appearance in
        windowBackground(for: appearance)
    }

    static let dynamicWebBackground = NSColor(name: NSColor.Name("TubeWebBackground")) { appearance in
        webBackground(for: appearance)
    }

    static func windowBackground(for appearance: NSAppearance) -> NSColor {
        isDark(appearance)
            ? NSColor(calibratedRed: 0.018, green: 0.020, blue: 0.036, alpha: 1)
            : NSColor(calibratedRed: 0.940, green: 0.950, blue: 0.970, alpha: 1)
    }

    static func webBackground(for appearance: NSAppearance) -> NSColor {
        isDark(appearance)
            ? NSColor(calibratedWhite: 0.030, alpha: 1)
            : NSColor(calibratedWhite: 1.000, alpha: 1)
    }

    static func hairline(for appearance: NSAppearance) -> NSColor {
        isDark(appearance)
            ? NSColor(calibratedWhite: 1.000, alpha: 0.07)
            : NSColor(calibratedWhite: 0.000, alpha: 0.09)
    }

    static func controlFill(for appearance: NSAppearance, pressed: Bool) -> NSColor {
        let alpha: CGFloat = pressed ? 0.18 : 0.10
        return isDark(appearance)
            ? NSColor(calibratedWhite: 1.000, alpha: alpha)
            : NSColor(calibratedWhite: 0.000, alpha: alpha)
    }

    static func overlayBackground(for appearance: NSAppearance) -> NSColor {
        isDark(appearance)
            ? NSColor(calibratedWhite: 0.060, alpha: 0.96)
            : NSColor(calibratedWhite: 0.985, alpha: 0.96)
    }

    static func overlayBorder(for appearance: NSAppearance) -> NSColor {
        isDark(appearance)
            ? NSColor(calibratedWhite: 1.000, alpha: 0.12)
            : NSColor(calibratedWhite: 0.000, alpha: 0.12)
    }

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

