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

    static func bezelBorder(for appearance: NSAppearance) -> NSColor {
        isDark(appearance)
            ? NSColor(calibratedRed: 0.190, green: 0.210, blue: 0.420, alpha: 0.90)
            : NSColor(calibratedRed: 0.690, green: 0.710, blue: 0.780, alpha: 0.90)
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

