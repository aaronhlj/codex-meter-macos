import AppKit
import CodexUsageCore
import Foundation

@main
struct StatusImageProbe {
    static func main() throws {
        let snapshot = UsageSnapshot(
            primary: UsageWindow(usedPercent: 16, windowMinutes: 300, resetsAt: nil),
            secondary: UsageWindow(usedPercent: 72, windowMinutes: 10_080, resetsAt: nil),
            planType: "plus",
            source: .appServer,
            updatedAt: Date()
        )
        let image = StatusItemImageFactory.make(snapshot: snapshot)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { throw ProbeError.renderFailed }
        try png.write(to: URL(fileURLWithPath: "/tmp/codex-meter-status-item.png"))
    }

    enum ProbeError: Error { case renderFailed }
}
