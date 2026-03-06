import SwiftUI
import AppKit

struct BuddhaIcon {
    static func makeImage(snoozed: Bool = false) -> NSImage {
        let s: CGFloat = 18.0
        let size = NSSize(width: s, height: s)
        let image = NSImage(size: size, flipped: false) { _ in
            let alpha: CGFloat = snoozed ? 0.4 : 1.0
            NSColor.black.withAlphaComponent(alpha).setFill()

            // Head
            let headPath = NSBezierPath()
            let headCx = s * 0.5
            let headCy = s * 0.80
            let headR = s * 0.105
            headPath.appendOval(in: NSRect(
                x: headCx - headR, y: headCy - headR,
                width: headR * 2, height: headR * 2
            ))
            headPath.fill()

            // Neck + torso + arms + crossed legs as one path
            let body = NSBezierPath()

            // Start at neck center
            body.move(to: p(s, 0.50, 0.71))

            // Left shoulder
            body.curve(to: p(s, 0.30, 0.58),
                       controlPoint1: p(s, 0.38, 0.70),
                       controlPoint2: p(s, 0.30, 0.65))

            // Left arm curving down to lap
            body.curve(to: p(s, 0.24, 0.42),
                       controlPoint1: p(s, 0.26, 0.53),
                       controlPoint2: p(s, 0.22, 0.48))

            // Left hand resting in lap
            body.curve(to: p(s, 0.35, 0.36),
                       controlPoint1: p(s, 0.25, 0.38),
                       controlPoint2: p(s, 0.30, 0.36))

            // Across lap (hands together)
            body.curve(to: p(s, 0.65, 0.36),
                       controlPoint1: p(s, 0.42, 0.34),
                       controlPoint2: p(s, 0.58, 0.34))

            // Right hand, right arm up
            body.curve(to: p(s, 0.76, 0.42),
                       controlPoint1: p(s, 0.70, 0.36),
                       controlPoint2: p(s, 0.75, 0.38))

            // Right arm up to shoulder
            body.curve(to: p(s, 0.70, 0.58),
                       controlPoint1: p(s, 0.78, 0.48),
                       controlPoint2: p(s, 0.74, 0.53))

            // Right shoulder back to neck
            body.curve(to: p(s, 0.50, 0.71),
                       controlPoint1: p(s, 0.70, 0.65),
                       controlPoint2: p(s, 0.62, 0.70))
            body.close()
            body.fill()

            // Crossed legs (lotus position)
            let legs = NSBezierPath()

            // Left leg - starts from left side of torso
            legs.move(to: p(s, 0.24, 0.40))

            // Left knee pointing out
            legs.curve(to: p(s, 0.10, 0.24),
                       controlPoint1: p(s, 0.16, 0.36),
                       controlPoint2: p(s, 0.10, 0.31))

            // Left shin curves under to center
            legs.curve(to: p(s, 0.38, 0.14),
                       controlPoint1: p(s, 0.10, 0.17),
                       controlPoint2: p(s, 0.22, 0.14))

            // Left foot tucks toward center
            legs.curve(to: p(s, 0.52, 0.18),
                       controlPoint1: p(s, 0.44, 0.14),
                       controlPoint2: p(s, 0.48, 0.15))

            // Cross over to right leg's foot
            legs.curve(to: p(s, 0.62, 0.14),
                       controlPoint1: p(s, 0.55, 0.15),
                       controlPoint2: p(s, 0.58, 0.14))

            // Right shin curves out to right knee
            legs.curve(to: p(s, 0.90, 0.24),
                       controlPoint1: p(s, 0.78, 0.14),
                       controlPoint2: p(s, 0.90, 0.17))

            // Right knee up to right side of torso
            legs.curve(to: p(s, 0.76, 0.40),
                       controlPoint1: p(s, 0.90, 0.31),
                       controlPoint2: p(s, 0.84, 0.36))

            // Close across the lap
            legs.line(to: p(s, 0.24, 0.40))
            legs.close()
            legs.fill()

            // Snoozed indicator
            if snoozed {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 6, weight: .bold),
                    .foregroundColor: NSColor.black.withAlphaComponent(0.7)
                ]
                NSAttributedString(string: "z", attributes: attrs)
                    .draw(at: CGPoint(x: s * 0.72, y: s * 0.68))
                let smallAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 4.5, weight: .bold),
                    .foregroundColor: NSColor.black.withAlphaComponent(0.5)
                ]
                NSAttributedString(string: "z", attributes: smallAttrs)
                    .draw(at: CGPoint(x: s * 0.82, y: s * 0.80))
            }

            return true
        }
        image.isTemplate = !snoozed
        return image
    }

    private static func p(_ s: CGFloat, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: s * x, y: s * y)
    }
}
