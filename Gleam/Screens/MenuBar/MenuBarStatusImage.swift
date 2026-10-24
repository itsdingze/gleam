import AppKit

enum MenuBarStatusImage {
    private static let iconSide: CGFloat = 15
    private static let dotDiameter: CGFloat = 6
    private static let ringWidth: CGFloat = 1.25
    private static let dotOverhang: CGFloat = 1.5

    static func make(isOn: Bool) -> NSImage {
        let glyph = NSImage(resource: isOn ? .menuBarCameraOn : .menuBarCameraOff)
        let canvas = NSSize(width: iconSide + dotOverhang, height: iconSide + dotOverhang)
        let image = NSImage(size: canvas, flipped: true) { _ in
            drawGlyph(glyph)
            cutRing()
            drawDot(color: isOn ? .systemGreen : .systemRed)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static var dotRect: NSRect {
        let origin = iconSide + dotOverhang - dotDiameter
        return NSRect(x: origin, y: origin, width: dotDiameter, height: dotDiameter)
    }

    private static func drawGlyph(_ glyph: NSImage) {
        let glyphRect = NSRect(x: 0, y: 0, width: iconSide, height: iconSide)
        glyph.draw(in: glyphRect)
        NSColor.labelColor.set()
        glyphRect.fill(using: .sourceAtop)
    }

    private static func cutRing() {
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        NSBezierPath(ovalIn: dotRect.insetBy(dx: -ringWidth, dy: -ringWidth)).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    }

    private static func drawDot(color: NSColor) {
        color.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }
}
