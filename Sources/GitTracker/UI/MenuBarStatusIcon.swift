import AppKit

enum MenuBarStatusIcon {
    static func image(breached: Bool) -> NSImage {
        let size = NSSize(width: 19, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let folderBase = NSImage(systemSymbolName: "folder", accessibilityDescription: nil) ?? NSImage()
        let folderConfigured = folderBase.withSymbolConfiguration(.init(pointSize: 13, weight: .semibold)) ?? folderBase
        let folder = folderConfigured.tinted(with: .labelColor)
        folder.draw(in: NSRect(x: 0, y: 1, width: 14, height: 14))

        let badgeBackgroundRect = NSRect(x: 9, y: -1, width: 11, height: 11)
        let badgeBackgroundPath = NSBezierPath(ovalIn: badgeBackgroundRect)
        NSColor.windowBackgroundColor.setFill()
        badgeBackgroundPath.fill()

        NSColor.windowBackgroundColor.setStroke()
        badgeBackgroundPath.lineWidth = 1
        badgeBackgroundPath.stroke()

        let badgeRect = NSRect(x: 9.5, y: -0.5, width: 10, height: 10)
        let badgePath = NSBezierPath(ovalIn: badgeRect)
        let badgeColor: NSColor = breached ? .systemYellow : .systemGreen
        badgeColor.setFill()
        badgePath.fill()

        let glyph = breached ? "!" : "✓"
        let glyphAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .black),
            .foregroundColor: breached ? NSColor.black : NSColor.white
        ]
        let glyphSize = glyph.size(withAttributes: glyphAttributes)
        let glyphRect = NSRect(
            x: badgeRect.midX - (glyphSize.width / 2),
            y: badgeRect.midY - (glyphSize.height / 2) - 0.2,
            width: glyphSize.width,
            height: glyphSize.height
        )
        glyph.draw(in: glyphRect, withAttributes: glyphAttributes)

        image.isTemplate = false
        return image
    }
}

private extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let output = NSImage(size: size)
        output.lockFocus()
        draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1)
        color.set()
        NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
        output.unlockFocus()
        output.isTemplate = false
        return output
    }
}
