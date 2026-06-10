import Foundation

private struct WireWindow: Decodable {
    let usedPercent: Int
    let windowMinutes: Int?
    let resetsAtSeconds: Int64?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        usedPercent = try container.decode(Int.self, forAnyKey: ["usedPercent", "used_percent"])
        windowMinutes = container.decodeIfPresent(Int.self, forAnyKey: ["windowDurationMins", "window_minutes"])
        resetsAtSeconds = container.decodeIfPresent(Int64.self, forAnyKey: ["resetsAt", "resets_at"])
    }

    var model: UsageWindow {
        UsageWindow(
            usedPercent: usedPercent,
            windowMinutes: windowMinutes,
            resetsAt: resetsAtSeconds.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }
}

private struct WireSnapshot: Decodable {
    let primary: WireWindow?
    let secondary: WireWindow?
    let planType: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        primary = container.decodeIfPresent(WireWindow.self, forAnyKey: ["primary"])
        secondary = container.decodeIfPresent(WireWindow.self, forAnyKey: ["secondary"])
        planType = container.decodeIfPresent(String.self, forAnyKey: ["planType", "plan_type"])
    }

    func model(source: UsageSource, updatedAt: Date) -> UsageSnapshot {
        UsageSnapshot(
            primary: primary?.model,
            secondary: secondary?.model,
            planType: planType,
            source: source,
            updatedAt: updatedAt
        )
    }
}

private struct DynamicKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private extension KeyedDecodingContainer where Key == DynamicKey {
    func key(_ names: [String]) -> DynamicKey? {
        names.lazy.compactMap(DynamicKey.init(stringValue:)).first { contains($0) }
    }

    func decode<T: Decodable>(_ type: T.Type, forAnyKey names: [String]) throws -> T {
        guard let key = key(names) else {
            throw DecodingError.keyNotFound(
                DynamicKey(stringValue: names[0])!,
                .init(codingPath: codingPath, debugDescription: "Missing \(names.joined(separator: " or "))")
            )
        }
        return try decode(type, forKey: key)
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forAnyKey names: [String]) -> T? {
        guard let key = key(names) else { return nil }
        return try? decodeIfPresent(type, forKey: key)
    }
}

public enum LocalSessionParser {
    public static func parseLatest(in data: Data) -> UsageSnapshot? {
        var latest: UsageSnapshot?
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()

        for line in data.split(separator: 0x0A) {
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                let timestamp = object["timestamp"] as? String,
                let date = formatter.date(from: timestamp),
                let payload = object["payload"] as? [String: Any],
                payload["type"] as? String == "token_count",
                let rateLimits = payload["rate_limits"],
                JSONSerialization.isValidJSONObject(rateLimits),
                let rateData = try? JSONSerialization.data(withJSONObject: rateLimits),
                let wire = try? decoder.decode(WireSnapshot.self, from: rateData)
            else { continue }

            let snapshot = wire.model(source: .localSession, updatedAt: date)
            if snapshot.hasUsage, latest == nil || snapshot.updatedAt > latest!.updatedAt {
                latest = snapshot
            }
        }
        return latest
    }
}

public enum AppServerUsageParser {
    public static func parseResult(_ data: Data, receivedAt: Date = Date()) throws -> UsageSnapshot {
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let object else { throw ParserError.invalidResponse }

        let selected: Any?
        if let buckets = object["rateLimitsByLimitId"] as? [String: Any], let codex = buckets["codex"] {
            selected = codex
        } else {
            selected = object["rateLimits"]
        }
        guard let selected, JSONSerialization.isValidJSONObject(selected) else {
            throw ParserError.missingRateLimits
        }
        let selectedData = try JSONSerialization.data(withJSONObject: selected)
        let wire = try JSONDecoder().decode(WireSnapshot.self, from: selectedData)
        let snapshot = wire.model(source: .appServer, updatedAt: receivedAt)
        guard snapshot.hasUsage else { throw ParserError.missingRateLimits }
        return snapshot
    }

    public enum ParserError: Error {
        case invalidResponse
        case missingRateLimits
    }
}
