import Foundation

public final class OfflineStore: @unchecked Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static func makeDefault() -> OfflineStore {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return OfflineStore(root: docs.appendingPathComponent("Offline", isDirectory: true))
    }

    private var bundlesDir: URL { root.appendingPathComponent("bundles", isDirectory: true) }
    private var tilesDir: URL { root.appendingPathComponent("tiles", isDirectory: true) }

    public func save(bundle: OfflineBundle) throws {
        try FileManager.default.createDirectory(at: bundlesDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bundle)
        try data.write(to: bundleURL(slug: bundle.slug), options: .atomic)
    }

    public func loadBundles() -> [OfflineBundle] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: bundlesDir, includingPropertiesForKeys: nil) else {
            return []
        }
        let decoder = JSONDecoder()
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0).decode(OfflineBundle.self, using: decoder) }
            .sorted { $0.preparedAt > $1.preparedAt }
    }

    public func delete(slug: String) throws {
        try? FileManager.default.removeItem(at: bundleURL(slug: slug))
    }

    public func isDownloaded(slug: String) -> Bool {
        FileManager.default.fileExists(atPath: bundleURL(slug: slug).path)
    }

    public func bundleURL(slug: String) -> URL {
        bundlesDir.appendingPathComponent("\(slug).json")
    }

    public func tileURL(_ ref: TileRef) -> URL {
        tilesDir
            .appendingPathComponent("\(ref.z)", isDirectory: true)
            .appendingPathComponent("\(ref.x)", isDirectory: true)
            .appendingPathComponent("\(ref.y).pbf")
    }

    public func hasTile(_ ref: TileRef) -> Bool {
        FileManager.default.fileExists(atPath: tileURL(ref).path)
    }

    @discardableResult
    public func downloadTiles(
        of bundle: OfflineBundle,
        client: SyncClient,
        concurrency: Int = 4,
        progress: (@Sendable (_ done: Int, _ total: Int) -> Void)? = nil
    ) async throws -> Int {
        let pending = bundle.tiles.filter { !hasTile($0) }
        if pending.isEmpty { return 0 }
        for ref in pending {
            try FileManager.default.createDirectory(
                at: tileURL(ref).deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }
        let total = bundle.tiles.count
        let alreadyDone = total - pending.count
        if alreadyDone > 0 { progress?(alreadyDone, total) }

        var completed = 0
        try await withThrowingTaskGroup(of: Void.self) { group in
            var iterator = pending.makeIterator()
            for _ in 0..<min(concurrency, pending.count) {
                guard let ref = iterator.next() else { break }
                group.addTask {
                    let data = try await client.tile(ref)
                    try data.write(to: self.tileURL(ref), options: .atomic)
                }
            }
            while let _ = try await group.next() {
                completed += 1
                progress?(alreadyDone + completed, total)
                if let ref = iterator.next() {
                    group.addTask {
                        let data = try await client.tile(ref)
                        try data.write(to: self.tileURL(ref), options: .atomic)
                    }
                }
            }
        }
        return pending.count
    }
}

private extension Data {
    func decode<T: Decodable>(_ type: T.Type, using decoder: JSONDecoder) throws -> T {
        try decoder.decode(T.self, from: self)
    }
}
