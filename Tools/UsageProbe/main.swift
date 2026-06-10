import Foundation

@main
struct UsageProbe {
    static func main() async throws {
        let client = CodexAppServerClient()
        let snapshots = try await withThrowingTaskGroup(of: UsageSnapshot.self) { group in
            for _ in 0..<5 {
                group.addTask { try await client.fetch() }
            }
            var values: [UsageSnapshot] = []
            for try await snapshot in group { values.append(snapshot) }
            return values
        }
        guard let snapshot = snapshots.first else { return }
        print("requests=\(snapshots.count) 5h=\(snapshot.primary?.remainingPercent.description ?? "--") 7d=\(snapshot.secondary?.remainingPercent.description ?? "--") plan=\(snapshot.planType ?? "unknown")")
        client.stop()
    }
}
