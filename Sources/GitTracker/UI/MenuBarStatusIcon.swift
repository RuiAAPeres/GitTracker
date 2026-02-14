import AppKit

enum MenuBarStatusIcon {
    @MainActor
    static func image(breached: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let folderBase = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil) ?? NSImage()
        let folderConfigured = folderBase.withSymbolConfiguration(.init(pointSize: 16, weight: .semibold)) ?? folderBase
        let folder = folderConfigured.tinted(with: folderTintColor())
        drawAspectFit(folder, in: NSRect(x: 0, y: 0.5, width: 16, height: 16))

        let statusSymbolName = breached ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
        let statusColor: NSColor = breached
            ? NSColor(calibratedRed: 0.84, green: 0.58, blue: 0.02, alpha: 1.0)
            : .systemGreen
        let statusBase = NSImage(systemSymbolName: statusSymbolName, accessibilityDescription: nil) ?? NSImage()
        let statusConfigured = statusBase.withSymbolConfiguration(.init(pointSize: 10, weight: .bold)) ?? statusBase
        let status = statusConfigured.tinted(with: statusColor)
        drawAspectFit(status, in: NSRect(x: 11, y: -0.5, width: 11, height: 11))

        image.isTemplate = false
        return image
    }

    @MainActor
    private static func folderTintColor() -> NSColor {
        NSColor.black.withAlphaComponent(0.82)
    }

    private static func drawAspectFit(_ image: NSImage, in rect: NSRect) {
        guard image.size.width > 0, image.size.height > 0 else {
            return
        }

        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let width = image.size.width * scale
        let height = image.size.height * scale
        let target = NSRect(
            x: rect.midX - (width / 2),
            y: rect.midY - (height / 2),
            width: width,
            height: height
        )
        image.draw(in: target)
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
