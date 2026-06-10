import AppKit
import CodexUsageCore
import Foundation
import ServiceManagement
import UserNotifications

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?
    @Published var launchAtLogin = false

    private let appServer = CodexAppServerClient()
    private var appServerSnapshot: UsageSnapshot?
    private var notificationState = NotificationThresholdState()
    private var tasks: [Task<Void, Never>] = []

    var isStale: Bool {
        snapshot.map { UsageMerger.isStale($0) } ?? false
    }

    func start() {
        guard tasks.isEmpty else { return }
        configurePushUpdates()
        configureLaunchAtLogin()
        requestNotificationPermission()

        tasks.append(Task { [weak self] in
            await self?.refreshAll()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await self?.refreshOnline()
            }
        })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        appServer.stop()
    }

    func refreshAll() async {
        await refreshOnline()
    }

    func refreshOnline() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        applyOnline(await result { try await appServer.fetch() })
        isRefreshing = false
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
            UserDefaults.standard.set(enabled, forKey: "launchAtLoginDesired")
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            errorMessage = "无法更改开机启动：\(error.localizedDescription)"
        }
    }

    func openCodex() {
        let url = URL(fileURLWithPath: "/Applications/Codex.app")
        if !NSWorkspace.shared.open(url) {
            errorMessage = "无法打开 /Applications/Codex.app"
        }
    }

    private func configurePushUpdates() {
        appServer.setSnapshotHandler { [weak self] snapshot in
            Task { @MainActor in self?.accept(snapshot) }
        }
    }

    private func configureLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        let key = "launchAtLoginDesired"
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(true, forKey: key)
        }
        if UserDefaults.standard.bool(forKey: key), !launchAtLogin {
            setLaunchAtLogin(true)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func applyOnline(_ value: Result<UsageSnapshot, Error>) {
        switch value {
        case .success(let snapshot): accept(snapshot)
        case .failure(let error):
            errorMessage = "实时服务连接失败：\(error.localizedDescription)"
        }
    }

    private func accept(_ newSnapshot: UsageSnapshot) {
        appServerSnapshot = appServerSnapshot.map {
            UsageMerger.mergeSparse(base: $0, update: newSnapshot)
        } ?? newSnapshot
        snapshot = appServerSnapshot
        if errorMessage?.hasPrefix("实时服务连接失败") == true { errorMessage = nil }
        if let snapshot { notifyIfNeeded(snapshot) }
    }

    private func notifyIfNeeded(_ snapshot: UsageSnapshot) {
        notify(window: snapshot.primary, kind: .primary, name: "5 小时额度")
        notify(window: snapshot.secondary, kind: .secondary, name: "7 天额度")
    }

    private func notify(window: UsageWindow?, kind: UsageWindowKind, name: String) {
        guard let window else { return }
        for threshold in notificationState.crossedThresholds(
            window: kind,
            remaining: window.remainingPercent,
            resetAt: window.resetsAt
        ) {
            let identifier = "\(kind)-\(threshold)-\(window.resetsAt?.timeIntervalSince1970 ?? 0)"
            let preferenceKey = "notification.sent.\(identifier)"
            guard !UserDefaults.standard.bool(forKey: preferenceKey) else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Codex \(name)不足"
            content.body = "剩余 \(window.remainingPercent)%（已低于 \(threshold)%）"
            content.sound = .default
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            ) { error in
                if error == nil {
                    UserDefaults.standard.set(true, forKey: preferenceKey)
                }
            }
        }
    }
}

private func result<T: Sendable>(_ operation: @Sendable () async throws -> T) async -> Result<T, Error> {
    do { return .success(try await operation()) }
    catch { return .failure(error) }
}
