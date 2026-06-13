import AppKit
import Combine
import CodexUsageCore
import SwiftUI

@main
struct CodexUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: StatusItemMetrics.width)
        statusItem = item
        if let button = item.button {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = StatusItemMetrics.popoverSize
        popover.contentViewController = NSHostingController(rootView: UsageMenuView(store: store))

        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in self?.updateStatusImage(snapshot) }
            .store(in: &cancellables)

        updateStatusImage(nil)
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateStatusImage(_ snapshot: UsageSnapshot?) {
        guard let button = statusItem?.button else { return }
        button.image = StatusItemImageFactory.make(snapshot: snapshot)
        let description = "Codex 5 小时：\(snapshot?.primary?.remainingPercent.description ?? "--")%，7 天：\(snapshot?.secondary?.remainingPercent.description ?? "--")%"
        button.toolTip = description
        button.setAccessibilityLabel(description)
    }
}
