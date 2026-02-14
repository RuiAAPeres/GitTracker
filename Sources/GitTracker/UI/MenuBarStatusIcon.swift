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

        let badgeRect = NSRect(x: 10, y: 0, width: 9, height: 9)
        let badgePath = NSBezierPath(ovalIn: badgeRect)
        (breached ? NSColor.systemYellow : NSColor.systemGreen).setFill()
        badgePath.fill()

        NSColor.windowBackgroundColor.setStroke()
        badgePath.lineWidth = 1
        badgePath.stroke()

        let glyphName = breached ? "exclamationmark" : "checkmark"
        let glyphBase = NSImage(systemSymbolName: glyphName, accessibilityDescription: nil) ?? NSImage()
        let glyphConfigured = glyphBase.withSymbolConfiguration(.init(pointSize: 6, weight: .black)) ?? glyphBase
        let glyphColor: NSColor = breached ? .black : .white
        let glyph = glyphConfigured.tinted(with: glyphColor)
        glyph.draw(in: badgeRect.insetBy(dx: 1.5, dy: 1.5))

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
