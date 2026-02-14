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

        let badgeBackgroundRect = NSRect(x: 9.5, y: -0.5, width: 10, height: 10)
        let badgeBackgroundPath = NSBezierPath(ovalIn: badgeBackgroundRect)
        NSColor.windowBackgroundColor.setFill()
        badgeBackgroundPath.fill()

        NSColor.windowBackgroundColor.setStroke()
        badgeBackgroundPath.lineWidth = 1
        badgeBackgroundPath.stroke()

        let statusSymbolName = breached ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
        let statusColor: NSColor = breached ? .systemYellow : .systemGreen
        let statusBase = NSImage(systemSymbolName: statusSymbolName, accessibilityDescription: nil) ?? NSImage()
        let statusConfigured = statusBase.withSymbolConfiguration(.init(pointSize: 9, weight: .bold)) ?? statusBase
        let status = statusConfigured.tinted(with: statusColor)
        status.draw(in: NSRect(x: 10, y: 0, width: 9, height: 9))

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
