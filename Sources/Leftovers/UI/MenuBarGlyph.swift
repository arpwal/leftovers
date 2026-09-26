import AppKit

/// The menu-bar glyph: an open dial whose needle shows how much memory is in
/// use. Drawn in code (crisp at every scale, no assets) as a template image,
/// so macOS tints it for light/dark menu bars. Deliberately light: thin
/// strokes, open at the bottom.
enum MenuBarGlyph {
    /// Needle positions are quantised so the image is only redrawn when the
    /// reading moves by a visible amount.
    private static let steps = 20
    private static var cache: [Int: NSImage] = [:]

    /// - Parameter fraction: memory in use, 0...1.
    @MainActor
    static func image(fraction: Double) -> NSImage {
        let step = Int((min(max(fraction, 0), 1) * Double(steps)).rounded())
        if let cached = cache[step] { return cached }
        let image = draw(fraction: Double(step) / Double(steps))
        cache[step] = image
        return image
    }

    private static func draw(fraction: Double) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()
            let center = NSPoint(x: 9, y: 8.4)
            // 270° arc, open at the bottom: from 225° over the top to -45°.
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: 6.6, startAngle: 225, endAngle: -45, clockwise: true)
            arc.lineWidth = 1.5
            arc.lineCapStyle = .round
            arc.stroke()
            // Needle: 0% points at 225°, 100% at -45°.
            let angle = (225 - 270 * fraction) * .pi / 180
            let needle = NSBezierPath()
            needle.move(to: center)
            needle.line(to: NSPoint(x: center.x + 4.6 * cos(angle), y: center.y + 4.6 * sin(angle)))
            needle.lineWidth = 1.6
            needle.lineCapStyle = .round
            needle.stroke()
            NSBezierPath(ovalIn: NSRect(x: center.x - 1.4, y: center.y - 1.4, width: 2.8, height: 2.8)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
