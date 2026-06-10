import AppKit
import CodexUsageCore
import SwiftUI

enum StatusItemImageFactory {
    private static let imageSize = NSSize(width: 76, height: 22)
    private static let segmentCount = 16

    static func make(snapshot: UsageSnapshot?) -> NSImage {
        let image = NSImage(size: imageSize, flipped: false) { _ in
            drawMeter(label: "5h", percent: snapshot?.primary?.remainingPercent, originX: 0)
            drawMeter(label: "7d", percent: snapshot?.secondary?.remainingPercent, originX: 39)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawMeter(label: String, percent: Int?, originX: CGFloat) {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 7.5, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ]
        NSString(string: label).draw(at: NSPoint(x: originX, y: 7), withAttributes: labelAttributes)

        let center = NSPoint(x: originX + 25.5, y: 11)
        let activeCount = SegmentedRing.activeSegments(
            remainingPercent: percent,
            segmentCount: segmentCount
        )
        let activeColor = percent.map { NSColor(UsageLevel(remainingPercent: $0)) }

        for index in 0..<segmentCount {
            let start = 90 - CGFloat(index) * 360 / CGFloat(segmentCount)
            let end = start - 14
            let path = NSBezierPath()
            path.appendArc(withCenter: center, radius: 8.5, startAngle: start, endAngle: end, clockwise: true)
            path.lineWidth = 2.6
            path.lineCapStyle = .butt
            (index < activeCount ? activeColor : NSColor.secondaryLabelColor.withAlphaComponent(0.25))?.setStroke()
            path.stroke()
        }

        let number = percent.map(String.init) ?? "--"
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 5.8, weight: .bold),
            .foregroundColor: NSColor.labelColor,
        ]
        let textSize = NSString(string: number).size(withAttributes: numberAttributes)
        NSString(string: number).draw(
            at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2),
            withAttributes: numberAttributes
        )
    }
}

extension Color {
    init(_ level: UsageLevel) {
        self.init(nsColor: NSColor(level))
    }
}

private extension NSColor {
    convenience init(_ level: UsageLevel) {
        switch level {
        case .high: self.init(red: 0.09, green: 0.53, blue: 0.23, alpha: 1)
        case .good: self.init(red: 0.45, green: 0.75, blue: 0.27, alpha: 1)
        case .medium: self.init(red: 0.89, green: 0.70, blue: 0.10, alpha: 1)
        case .low: self.init(red: 0.93, green: 0.49, blue: 0.10, alpha: 1)
        case .critical: self.init(red: 0.85, green: 0.21, blue: 0.21, alpha: 1)
        }
    }
}
