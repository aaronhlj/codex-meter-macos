import AppKit
import CodexUsageCore
import SwiftUI

enum StatusItemMetrics {
    static let width: CGFloat = 58
    static let popoverSize = NSSize(width: 300, height: 250)
}

enum StatusItemImageFactory {
    private static let imageSize = NSSize(width: 50, height: 22)

    static func make(snapshot: UsageSnapshot?) -> NSImage {
        let image = NSImage(size: imageSize, flipped: false) { _ in
            drawDial(percent: snapshot?.primary?.remainingPercent, centerX: 12)
            drawDial(percent: snapshot?.secondary?.remainingPercent, centerX: 38)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawDial(percent: Int?, centerX: CGFloat) {
        let center = NSPoint(x: centerX, y: 11)
        let radius: CGFloat = 8

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = 2
        track.lineCapStyle = .round
        NSColor.secondaryLabelColor.withAlphaComponent(0.22).setStroke()
        track.stroke()

        let clamped = percent.map { min(100, max(0, $0)) }
        if let clamped, clamped > 0 {
            let progress = NSBezierPath()
            let endAngle = 90 - CGFloat(clamped) / 100 * 360
            progress.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: 90,
                endAngle: endAngle,
                clockwise: true
            )
            progress.lineWidth = 2
            progress.lineCapStyle = .round
            NSColor(UsageLevel(remainingPercent: clamped)).setStroke()
            progress.stroke()
        }

        let number = clamped.map(String.init) ?? "--"
        let fontSize: CGFloat = number.count >= 3 ? 5.4 : 6.4
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.labelColor,
        ]
        let textSize = NSString(string: number).size(withAttributes: numberAttributes)
        NSString(string: number).draw(
            at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2 - 0.2),
            withAttributes: numberAttributes
        )
    }
}

private struct ThinProgressBar: View {
    let value: Int?
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.16))
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * CGFloat(clampedValue) / 100)
            }
        }
        .frame(height: 5)
        .accessibilityLabel("Remaining usage")
        .accessibilityValue(value.map { "\($0)%" } ?? "Unknown")
    }

    private var clampedValue: Int {
        min(100, max(0, value ?? 0))
    }
}

struct CompactUsageBar: View {
    let title: String
    let window: UsageWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(window.map { "\($0.remainingPercent)%" } ?? "--")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Text(resetDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ThinProgressBar(value: window?.remainingPercent, tint: color)
        }
    }

    private var color: Color {
        guard let remaining = window?.remainingPercent else { return .secondary }
        return Color(UsageLevel(remainingPercent: remaining))
    }

    private var resetDescription: String {
        guard let reset = window?.resetsAt else { return "reset --" }
        return "reset \(reset.formatted(date: .omitted, time: .shortened))"
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
