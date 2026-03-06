import SwiftUI
import AppKit

struct BuddhaIcon {
    static func makeImage(snoozed: Bool = false) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let scale: CGFloat = 18.0
            context.translateBy(x: 0, y: 0)

            // Draw a minimal seated buddha silhouette
            let path = NSBezierPath()

            // Head (circle)
            let headCenter = CGPoint(x: scale * 0.5, y: scale * 0.82)
            let headRadius = scale * 0.12
            path.appendOval(in: NSRect(
                x: headCenter.x - headRadius,
                y: headCenter.y - headRadius,
                width: headRadius * 2,
                height: headRadius * 2
            ))

            // Body (triangle-ish seated form)
            let bodyPath = NSBezierPath()
            // Shoulders
            bodyPath.move(to: CGPoint(x: scale * 0.5, y: scale * 0.72))
            // Left shoulder
            bodyPath.curve(to: CGPoint(x: scale * 0.18, y: scale * 0.38),
                          controlPoint1: CGPoint(x: scale * 0.28, y: scale * 0.68),
                          controlPoint2: CGPoint(x: scale * 0.18, y: scale * 0.55))
            // Left knee
            bodyPath.curve(to: CGPoint(x: scale * 0.08, y: scale * 0.22),
                          controlPoint1: CGPoint(x: scale * 0.14, y: scale * 0.32),
                          controlPoint2: CGPoint(x: scale * 0.08, y: scale * 0.28))
            // Base left
            bodyPath.curve(to: CGPoint(x: scale * 0.22, y: scale * 0.12),
                          controlPoint1: CGPoint(x: scale * 0.08, y: scale * 0.15),
                          controlPoint2: CGPoint(x: scale * 0.14, y: scale * 0.12))
            // Base center
            bodyPath.line(to: CGPoint(x: scale * 0.78, y: scale * 0.12))
            // Base right
            bodyPath.curve(to: CGPoint(x: scale * 0.92, y: scale * 0.22),
                          controlPoint1: CGPoint(x: scale * 0.86, y: scale * 0.12),
                          controlPoint2: CGPoint(x: scale * 0.92, y: scale * 0.15))
            // Right knee
            bodyPath.curve(to: CGPoint(x: scale * 0.82, y: scale * 0.38),
                          controlPoint1: CGPoint(x: scale * 0.92, y: scale * 0.28),
                          controlPoint2: CGPoint(x: scale * 0.86, y: scale * 0.32))
            // Right shoulder back to top
            bodyPath.curve(to: CGPoint(x: scale * 0.5, y: scale * 0.72),
                          controlPoint1: CGPoint(x: scale * 0.82, y: scale * 0.55),
                          controlPoint2: CGPoint(x: scale * 0.72, y: scale * 0.68))
            bodyPath.close()

            let alpha: CGFloat = snoozed ? 0.4 : 1.0
            NSColor.black.withAlphaComponent(alpha).setFill()
            path.fill()
            bodyPath.fill()

            // Draw "zzz" when snoozed
            if snoozed {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 6, weight: .bold),
                    .foregroundColor: NSColor.black.withAlphaComponent(0.7)
                ]
                let zzz = NSAttributedString(string: "z", attributes: attrs)
                zzz.draw(at: CGPoint(x: scale * 0.72, y: scale * 0.7))
                let zz = NSAttributedString(string: "z", attributes: [
                    .font: NSFont.systemFont(ofSize: 5, weight: .bold),
                    .foregroundColor: NSColor.black.withAlphaComponent(0.5)
                ])
                zz.draw(at: CGPoint(x: scale * 0.8, y: scale * 0.82))
            }

            return true
        }
        image.isTemplate = !snoozed
        return image
    }
}
