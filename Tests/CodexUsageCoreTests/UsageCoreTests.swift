import Foundation
import Testing
@testable import CodexUsageCore

@Test func usageWindowClampsRemainingPercent() {
    #expect(UsageWindow(usedPercent: 7, windowMinutes: 300, resetsAt: nil).remainingPercent == 93)
    #expect(UsageWindow(usedPercent: 140, windowMinutes: 300, resetsAt: nil).remainingPercent == 0)
    #expect(UsageWindow(usedPercent: -5, windowMinutes: 300, resetsAt: nil).remainingPercent == 100)
}

@Test func localParserFindsLatestValidRateLimitEvent() throws {
    let input = """
    {"timestamp":"2026-06-10T10:00:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":10,"window_minutes":300,"resets_at":1781089333},"secondary":{"used_percent":60,"window_minutes":10080,"resets_at":1781146054},"plan_type":"plus"}}}
    this line is incomplete {
    {"timestamp":"2026-06-10T10:02:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":12,"window_minutes":300,"resets_at":1781089333},"secondary":{"used_percent":64,"window_minutes":10080,"resets_at":1781146054},"plan_type":"plus"}}}
    """

    let snapshot = try #require(LocalSessionParser.parseLatest(in: Data(input.utf8)))
    #expect(snapshot.primary?.remainingPercent == 88)
    #expect(snapshot.secondary?.remainingPercent == 36)
    #expect(snapshot.planType == "plus")
    #expect(snapshot.source == .localSession)
}

@Test func appServerParserPrefersCodexBucket() throws {
    let input = """
    {"rateLimits":{"limitId":"legacy","primary":{"usedPercent":50,"windowDurationMins":300}},"rateLimitsByLimitId":{"codex":{"limitId":"codex","planType":"pro","primary":{"usedPercent":6,"windowDurationMins":300,"resetsAt":1781089333},"secondary":{"usedPercent":21,"windowDurationMins":10080,"resetsAt":1781146054}}}}
    """

    let snapshot = try AppServerUsageParser.parseResult(Data(input.utf8), receivedAt: Date(timeIntervalSince1970: 1_781_080_000))
    #expect(snapshot.primary?.remainingPercent == 94)
    #expect(snapshot.secondary?.remainingPercent == 79)
    #expect(snapshot.planType == "pro")
    #expect(snapshot.source == .appServer)
}

@Test func mergerUsesNewestValidSnapshot() {
    let old = UsageSnapshot(primary: nil, secondary: nil, planType: nil, source: .appServer, updatedAt: Date(timeIntervalSince1970: 100))
    let local = UsageSnapshot(primary: UsageWindow(usedPercent: 20, windowMinutes: 300, resetsAt: nil), secondary: nil, planType: "plus", source: .localSession, updatedAt: Date(timeIntervalSince1970: 200))

    #expect(UsageMerger.newest(appServer: old, local: local) == local)
    #expect(UsageMerger.isStale(local, now: Date(timeIntervalSince1970: 1_101)))
    #expect(!UsageMerger.isStale(local, now: Date(timeIntervalSince1970: 1_099)))
}

@Test func sparseAppServerUpdatePreservesMissingFields() {
    let original = UsageSnapshot(
        primary: UsageWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil),
        secondary: UsageWindow(usedPercent: 60, windowMinutes: 10_080, resetsAt: nil),
        planType: "plus",
        source: .appServer,
        updatedAt: Date(timeIntervalSince1970: 100)
    )
    let sparse = UsageSnapshot(
        primary: UsageWindow(usedPercent: 11, windowMinutes: 300, resetsAt: nil),
        secondary: nil,
        planType: nil,
        source: .appServer,
        updatedAt: Date(timeIntervalSince1970: 200)
    )

    let merged = UsageMerger.mergeSparse(base: original, update: sparse)
    #expect(merged.primary?.usedPercent == 11)
    #expect(merged.secondary?.usedPercent == 60)
    #expect(merged.planType == "plus")
    #expect(merged.updatedAt == sparse.updatedAt)
}

@Test func notificationStateEmitsEachThresholdOncePerReset() {
    var state = NotificationThresholdState()
    let reset = Date(timeIntervalSince1970: 2_000)

    #expect(state.crossedThresholds(window: .primary, remaining: 19, resetAt: reset) == [20])
    #expect(state.crossedThresholds(window: .primary, remaining: 18, resetAt: reset).isEmpty)
    #expect(state.crossedThresholds(window: .primary, remaining: 9, resetAt: reset) == [10])
    #expect(state.crossedThresholds(window: .primary, remaining: 8, resetAt: Date(timeIntervalSince1970: 3_000)) == [20, 10])
}

@Test func rpcEnvelopeExtractsMatchingResultAndIgnoresNotifications() throws {
    let notification = Data(#"{"method":"account/rateLimits/updated","params":{}}"#.utf8)
    let response = Data(#"{"id":42,"result":{"rateLimits":{"primary":{"usedPercent":8}}}}"#.utf8)

    #expect(try RPCEnvelope.parse(notification).response == nil)
    let parsed = try #require(RPCEnvelope.parse(response).response)
    #expect(parsed.id == 42)
    let result = try #require(parsed.result)
    #expect(String(decoding: result, as: UTF8.self).contains("rateLimits"))
}

@Test func rpcEnvelopeExtractsErrorResponses() throws {
    let input = Data(#"{"id":9,"error":{"code":-32603,"message":"not logged in"}}"#.utf8)
    let parsed = try #require(RPCEnvelope.parse(input).response)
    #expect(parsed.id == 9)
    #expect(parsed.result == nil)
    #expect(parsed.errorMessage == "not logged in")
}

@Test func usageLevelUsesRequestedColorBoundaries() {
    #expect(UsageLevel(remainingPercent: 100) == .high)
    #expect(UsageLevel(remainingPercent: 75) == .high)
    #expect(UsageLevel(remainingPercent: 74) == .good)
    #expect(UsageLevel(remainingPercent: 50) == .good)
    #expect(UsageLevel(remainingPercent: 49) == .medium)
    #expect(UsageLevel(remainingPercent: 30) == .medium)
    #expect(UsageLevel(remainingPercent: 29) == .low)
    #expect(UsageLevel(remainingPercent: 10) == .low)
    #expect(UsageLevel(remainingPercent: 9) == .critical)
    #expect(UsageLevel(remainingPercent: -1) == .critical)
}

@Test func segmentedRingRoundsUpVisibleProgress() {
    #expect(SegmentedRing.activeSegments(remainingPercent: nil, segmentCount: 16) == 0)
    #expect(SegmentedRing.activeSegments(remainingPercent: 0, segmentCount: 16) == 0)
    #expect(SegmentedRing.activeSegments(remainingPercent: 1, segmentCount: 16) == 1)
    #expect(SegmentedRing.activeSegments(remainingPercent: 50, segmentCount: 16) == 8)
    #expect(SegmentedRing.activeSegments(remainingPercent: 84, segmentCount: 16) == 14)
    #expect(SegmentedRing.activeSegments(remainingPercent: 100, segmentCount: 16) == 16)
}

@Test func localProviderChoosesNewestEventAcrossCandidateFiles() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let newerEvent = directory.appendingPathComponent("newer-event.jsonl")
    let newerMtime = directory.appendingPathComponent("newer-mtime.jsonl")
    try Data(localEvent(timestamp: "2026-06-10T10:05:00Z", used: 12).utf8).write(to: newerEvent)
    try Data(localEvent(timestamp: "2026-06-10T10:01:00Z", used: 40).utf8).write(to: newerMtime)
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: newerEvent.path)
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 200)], ofItemAtPath: newerMtime.path)

    let snapshot = try await LocalSessionProvider(sessionsURL: directory, maximumFiles: 10).fetch()
    #expect(snapshot.primary?.usedPercent == 12)
}

@Test func localProviderRetainsCachedSnapshotWhenNewTailHasNoUsageEvent() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let file = directory.appendingPathComponent("active.jsonl")
    try Data(localEvent(timestamp: "2026-06-10T10:05:00Z", used: 12).utf8).write(to: file)
    let provider = LocalSessionProvider(sessionsURL: directory, maximumFiles: 1, tailBytes: 512)
    #expect(try await provider.fetch().primary?.usedPercent == 12)

    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data((String(repeating: "x", count: 700) + "\n").utf8))
    try handle.close()

    #expect(try await provider.fetch().primary?.usedPercent == 12)
}

private func localEvent(timestamp: String, used: Int) -> String {
    #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":\#(used),"window_minutes":300}}}}"#
}
