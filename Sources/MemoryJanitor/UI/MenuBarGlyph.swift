import AppKit

/// The menu-bar glyph: a memory chip with a sparkle, drawn in code so it is
/// crisp at every scale. A template image, so macOS tints it for light/dark
/// menu bars and the highlighted state automatically.
enum MenuBarGlyph {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()
            drawChip()
            drawPins()
            sparkle(center: NSPoint(x: 9, y: 9), radius: 3).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()

    private static func drawChip() {
        let body = NSBezierPath(roundedRect: NSRect(x: 4.5, y: 4.5, width: 9, height: 9), xRadius: 2.4, yRadius: 2.4)
        body.lineWidth = 1.4
        body.stroke()
    }

    /// Three short pins per side.
    private static func drawPins() {
        let pins = NSBezierPath()
        pins.lineWidth = 1.2
        pins.lineCapStyle = .round
        for index in 0..<3 {
            let offset = 6.5 + CGFloat(index) * 2.5
            for (from, to) in [((offset, 4.2), (offset, 2)), ((offset, 13.8), (offset, 16)),
                               ((4.2, offset), (2, offset)), ((13.8, offset), (16, offset))] {
                pins.move(to: NSPoint(x: from.0, y: from.1))
                pins.line(to: NSPoint(x: to.0, y: to.1))
            }
        }
        pins.stroke()
    }

    /// Four-point star with concave sides.
    private static func sparkle(center c: NSPoint, radius r: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let pinch = r * 0.14
        let tips = [NSPoint(x: c.x, y: c.y + r), NSPoint(x: c.x + r, y: c.y),
                    NSPoint(x: c.x, y: c.y - r), NSPoint(x: c.x - r, y: c.y)]
        path.move(to: tips[0])
        for index in 0..<4 {
            let next = tips[(index + 1) % 4]
            let control = NSPoint(x: c.x + (index == 0 || index == 1 ? pinch : -pinch),
                                  y: c.y + (index == 0 || index == 3 ? pinch : -pinch))
            path.curve(to: next, controlPoint1: control, controlPoint2: control)
        }
        path.close()
        return path
    }
}
