import Foundation
import Testing
@testable import OpenactiveCore

struct OpenactiveCoreTests {
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    @Test func decodesPreparedTripsResponse() throws {
        let data = try fixture("prepared.json")
        let response = try JSONDecoder().decode(PreparedTripsResponse.self, from: data)
        #expect(response.trips.count == 2)
        let trip = try #require(response.trips.first)
        #expect(trip.slug == "karwendel-loop-sample")
        #expect(trip.bundleUrl == "/api/tours/karwendel-loop-sample/bundle")
        #expect(trip.stats.distanceKm == 4.11)
        #expect(trip.stats.ascentM == 1118)
        #expect(trip.stats.maxEleM == 1938)
        #expect(trip.stats.points == 13)
    }

    @Test func decodesBundleResponse() throws {
        let data = try fixture("bundle.json")
        let response = try JSONDecoder().decode(BundleResponse.self, from: data)
        let bundle = response.bundle
        #expect(bundle.slug == "karwendel-loop-sample")
        #expect(bundle.zoomMin == 11)
        #expect(bundle.zoomMax == 15)
        #expect(bundle.stats.points == 13)
        #expect(bundle.points.count == bundle.stats.points)
        #expect(bundle.points.allSatisfy { $0.count == 2 })
        #expect(bundle.tiles.count > 0)
        #expect(bundle.tiles.allSatisfy { $0.z >= 11 && $0.z <= 15 })
    }

    @Test func haversine() {
        let meters = haversineMeters(lon1: 11.0, lat1: 47.0, lon2: 12.0, lat2: 47.0)
        #expect(abs(meters - 74_600) < 3_000)
        let kmPerDegreeLat = haversineMeters(lon1: 0, lat1: 47.0, lon2: 0, lat2: 48.0) / 1000
        #expect(abs(kmPerDegreeLat - 111) < 1)
    }

    @Test func distanceToTrack() {
        let track = [[11.40, 47.27], [11.41, 47.28], [11.42, 47.29]]
        let onRoute = OpenactiveCore.distanceToTrack(lon: 11.41, lat: 47.28, track: track)
        #expect(onRoute.meters < 5)
        let offRoute = OpenactiveCore.distanceToTrack(lon: 11.5, lat: 47.4, track: track)
        #expect(offRoute.meters > 10_000)
    }

    @Test func offlineStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("oa-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = OfflineStore(root: dir)

        let bundle = OfflineBundle(
            slug: "test-tour", title: "Test", description: "",
            preparedAt: "2026-11-18T12:00:00.000Z",
            points: [[11.4, 47.27]], stats: TourStats(
                distanceKm: 1, ascentM: 10, descentM: 10,
                minEleM: 600, maxEleM: 700, points: 1
            ),
            zoomMin: 11, zoomMax: 15, tileCount: 2, estSizeMb: 0.1,
            tileCacheBase: "http://192.168.178.32:3456/api/tiles",
            tiles: [TileRef(z: 11, x: 1099, y: 743), TileRef(z: 15, x: 17585, y: 11896)]
        )

        #expect(!store.isDownloaded(slug: "test-tour"))
        try store.save(bundle: bundle)
        #expect(store.isDownloaded(slug: "test-tour"))

        let loaded = store.loadBundles()
        #expect(loaded.count == 1)
        #expect(loaded.first?.slug == "test-tour")
        #expect(loaded.first?.tiles.count == 2)

        let tileURL = store.tileURL(bundle.tiles[1])
        #expect(tileURL.path == dir
            .appendingPathComponent("tiles/15/17585/11896.pbf", isDirectory: false).path)
        #expect(!store.hasTile(bundle.tiles[0]))

        try store.delete(slug: "test-tour")
        #expect(!store.isDownloaded(slug: "test-tour"))
    }
}
