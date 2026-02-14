import AppKit

enum MenuBarStatusIcon {
    @MainActor
    static func image(breached: Bool) -> NSImage {
        let size = NSSize(width: 19, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let folderBase = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil) ?? NSImage()
        let folderConfigured = folderBase.withSymbolConfiguration(.init(pointSize: 13, weight: .semibold)) ?? folderBase
        let folder = folderConfigured.tinted(with: folderTintColor())
        folder.draw(in: NSRect(x: 0, y: 1, width: 14, height: 14))

        let statusSymbolName = breached ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
        let statusColor: NSColor = breached ? .systemYellow : .systemGreen
        let statusBase = NSImage(systemSymbolName: statusSymbolName, accessibilityDescription: nil) ?? NSImage()
        let statusConfigured = statusBase.withSymbolConfiguration(.init(pointSize: 10, weight: .bold)) ?? statusBase
        let status = statusConfigured.tinted(with: statusColor)
        status.draw(in: NSRect(x: 9, y: -1, width: 11, height: 11))

        image.isTemplate = false
        return image
    }

    @MainActor
    private static func folderTintColor() -> NSColor {
        NSColor.black.withAlphaComponent(0.82)
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
