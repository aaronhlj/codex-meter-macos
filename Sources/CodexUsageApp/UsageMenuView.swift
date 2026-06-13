import CodexUsageCore
import SwiftUI

struct UsageMenuView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let snapshot = store.snapshot {
                CompactUsageBar(title: "5h", window: snapshot.primary)
                CompactUsageBar(title: "7d", window: snapshot.secondary)
                footer(snapshot)
            } else {
                emptyState
            }

            if let error = store.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    Task { await store.refreshAll() }
                } label: {
                    Label(store.isRefreshing ? "刷新中" : "刷新", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshing)

                Button("打开 Codex") { store.openCodex() }

                Spacer()

                Button("退出") { NSApplication.shared.terminate(nil) }
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: StatusItemMetrics.popoverSize.width)
        .onAppear { Task { await store.refreshOnline() } }
    }

    private var header: some View {
        HStack {
            Text("Codex Meter")
                .font(.headline)
            Spacer()
            Toggle("开机启动", isOn: Binding(
                get: { store.launchAtLogin },
                set: { store.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .font(.caption)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("--")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(store.errorMessage ?? "请确认 Codex 已登录并正在运行。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func footer(_ snapshot: UsageSnapshot) -> some View {
        HStack {
            Text("Updated \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
            if store.isStale {
                Text("数据可能过期")
                    .foregroundStyle(.orange)
            }
            Spacer()
            if let plan = snapshot.planType?.uppercased() {
                Text(plan)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
