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
    private let local = LocalSessionProvider()
    private var appServerSnapshot: UsageSnapshot?
    private var localSnapshot: UsageSnapshot?
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
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshLocal()
                try? await Task.sleep(for: .seconds(10))
            }
        })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        appServer.stop()
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        async let online = result { try await self.appServer.fetch() }
        async let localResult = result { try await self.local.fetch() }
        let (onlineValue, localValue) = await (online, localResult)
        applyOnline(onlineValue)
        applyLocal(localValue)
        isRefreshing = false
    }

    func refreshOnline() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        applyOnline(await result { try await appServer.fetch() })
        isRefreshing = false
    }

    func refreshLocal() async {
        applyLocal(await result { try await local.fetch() }, reportError: snapshot == nil)
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
            Task { @MainActor in self?.accept(snapshot, online: true) }
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
        case .success(let snapshot): accept(snapshot, online: true)
        case .failure(let error):
            if snapshot == nil { errorMessage = "在线刷新失败：\(error.localizedDescription)" }
        }
    }

    private func applyLocal(_ value: Result<UsageSnapshot, Error>, reportError: Bool = true) {
        switch value {
        case .success(let snapshot): accept(snapshot, online: false)
        case .failure(let error):
            if reportError { errorMessage = "本地读取失败：\(error.localizedDescription)" }
        }
    }

    private func accept(_ newSnapshot: UsageSnapshot, online: Bool) {
        if online {
            appServerSnapshot = appServerSnapshot.map {
                UsageMerger.mergeSparse(base: $0, update: newSnapshot)
            } ?? newSnapshot
        } else {
            localSnapshot = newSnapshot
        }
        snapshot = UsageMerger.newest(appServer: appServerSnapshot, local: localSnapshot)
        if errorMessage?.hasPrefix("在线刷新失败") == true ||
            errorMessage?.hasPrefix("本地读取失败") == true {
            errorMessage = nil
        }
        notifyIfNeeded(newSnapshot)
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
