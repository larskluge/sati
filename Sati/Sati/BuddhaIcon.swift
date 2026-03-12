#if os(macOS)
import SwiftUI
import AppKit

struct BuddhaIcon {
    static func makeImage(snoozed: Bool = false) -> NSImage {
        let s: CGFloat = 18.0
        let size = NSSize(width: s, height: s)

        let resourcePath = Bundle.main.bundlePath + "/Contents/Resources/buddha@2x.png"
        guard let baseImage = NSImage(contentsOfFile: resourcePath) else {
            let fallback = NSImage(size: size, flipped: false) { _ in
                NSColor.black.setFill()
                NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 12, height: 12)).fill()
                return true
            }
            fallback.isTemplate = true
            return fallback
        }

        let image = NSImage(size: size, flipped: false) { rect in
            let alpha: CGFloat = snoozed ? 0.4 : 1.0
            baseImage.draw(in: rect,
                          from: NSRect(origin: .zero, size: baseImage.size),
                          operation: .sourceOver,
                          fraction: alpha)

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
}
#endif
