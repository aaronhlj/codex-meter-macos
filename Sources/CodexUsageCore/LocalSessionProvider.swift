import Foundation

public actor LocalSessionProvider: UsageProvider {
    public let sessionsURL: URL
    public let maximumFiles: Int
    public let tailBytes: Int

    private struct CachedFile {
        let size: Int64
        let modificationDate: Date
        let snapshot: UsageSnapshot?
    }

    private var cache: [URL: CachedFile] = [:]

    public init(
        sessionsURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true),
        maximumFiles: Int = 12,
        tailBytes: Int = 512 * 1024
    ) {
        self.sessionsURL = sessionsURL
        self.maximumFiles = maximumFiles
        self.tailBytes = tailBytes
    }

    public func fetch() async throws -> UsageSnapshot {
        let candidates = try candidateFiles()
        let candidateURLs = Set(candidates.map(\.url))
        cache = cache.filter { candidateURLs.contains($0.key) }

        var snapshots: [UsageSnapshot] = []
        for candidate in candidates {
            if let cached = cache[candidate.url],
               cached.size == candidate.size,
               cached.modificationDate == candidate.modificationDate {
                if let snapshot = cached.snapshot { snapshots.append(snapshot) }
                continue
            }

            let data = try readTail(of: candidate.url, size: candidate.size)
            let snapshot = LocalSessionParser.parseLatest(in: data) ?? cache[candidate.url]?.snapshot
            cache[candidate.url] = CachedFile(
                size: candidate.size,
                modificationDate: candidate.modificationDate,
                snapshot: snapshot
            )
            if let snapshot { snapshots.append(snapshot) }
        }

        guard let latest = snapshots.max(by: { $0.updatedAt < $1.updatedAt }) else {
            throw ProviderError.noUsageData
        }
        return latest
    }

    private func candidateFiles() throws -> [(url: URL, size: Int64, modificationDate: Date)] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { throw ProviderError.sessionsUnavailable }

        var files: [(URL, Int64, Date)] = []
        while let file = enumerator.nextObject() as? URL {
            guard file.pathExtension == "jsonl",
                  let values = try? file.resourceValues(forKeys: keys),
                  values.isRegularFile == true
            else { continue }
            files.append((file, Int64(values.fileSize ?? 0), values.contentModificationDate ?? .distantPast))
        }
        return files.sorted(by: { $0.2 > $1.2 }).prefix(maximumFiles).map { $0 }
    }

    private func readTail(of url: URL, size: Int64) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let start = max(0, size - Int64(tailBytes))
        try handle.seek(toOffset: UInt64(start))
        return try handle.readToEnd() ?? Data()
    }

    public enum ProviderError: LocalizedError {
        case sessionsUnavailable
        case noUsageData

        public var errorDescription: String? {
            switch self {
            case .sessionsUnavailable: "无法读取 Codex 会话目录"
            case .noUsageData: "尚未找到 Codex 用量记录"
            }
        }
    }
}
