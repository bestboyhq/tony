import AppKit

/// Tony's mark, the app icon's mic (a capsule head over a smile on a short stem), as the menu bar icon.
enum Mark {
    /// An 18 pt template image, drawn in code so it is crisp at every scale.
    /// While listening it inverts to a filled tile with the mark cut out, like Grip's recording icon,
    /// so the state reads at a glance in a monochrome menu bar.
    @MainActor static func menuBarImage(listening: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let shape = listening
                ? CGPath(roundedRect: CGRect(x: 0.5, y: 0.5, width: 17, height: 17), cornerWidth: 4.2, cornerHeight: 4.2, transform: nil)
                    .subtracting(mic(head: CGSize(width: 4, height: 6.4), gap: 1.2, stem: 1.2, line: 1.5))
                : mic(head: CGSize(width: 6, height: 9.6), gap: 1.4, stem: 1.8, line: 1.7)
            NSColor.black.set()
            NSBezierPath(cgPath: shape).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = listening ? "Tony, listening" : "Tony"
        return image
    }

    /// The mic in the 18 pt square (y down): a capsule `head`, a smile `gap` away hugging its lower end with tips 15° below
    /// that end's center, and a stem showing `stem` below the smile, all strokes `line` wide with round ends.
    /// Resting the head on a pixel row keeps the gap under it clear at 1x; the even head width keeps its sides crisp.
    private static func mic(head: CGSize, gap: CGFloat, stem: CGFloat, line: CGFloat) -> CGPath {
        let r = head.width / 2, smile = r + gap + line / 2 // radius of the smile's centerline
        let above = head.height - r, below = smile + stem + line / 2 // extent around the head's lower circle center
        let y = (9 - (below - above) / 2 + r).rounded() - r // that center, the mark centered with the head on a pixel row
        let strokes = NSBezierPath()
        strokes.appendArc(withCenter: NSPoint(x: 9, y: y), radius: smile, startAngle: 15, endAngle: 165) // through the bottom
        strokes.move(to: NSPoint(x: 9, y: y + smile))
        strokes.line(to: NSPoint(x: 9, y: y + smile + stem))
        let capsule = CGRect(x: 9 - r, y: y + r - head.height, width: head.width, height: head.height)
        return strokes.cgPath.copy(strokingWithWidth: line, lineCap: .round, lineJoin: .round, miterLimit: 10)
            .union(CGPath(roundedRect: capsule, cornerWidth: r, cornerHeight: r, transform: nil))
    }
}
