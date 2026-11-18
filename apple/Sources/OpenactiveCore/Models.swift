import Foundation

public struct TourStats: Codable, Equatable, Sendable {
    public let distanceKm: Double
    public let ascentM: Double
    public let descentM: Double
    public let minEleM: Double?
    public let maxEleM: Double?
    public let points: Int
}

public struct TileRef: Codable, Equatable, Hashable, Sendable {
    public let z: Int
    public let x: Int
    public let y: Int
}

public struct OfflineBundle: Codable, Equatable, Sendable {
    public let slug: String
    public let title: String
    public let description: String
    public let preparedAt: String
    public let points: [[Double]]
    public let stats: TourStats
    public let zoomMin: Int
    public let zoomMax: Int
    public let tileCount: Int
    public let estSizeMb: Double
    public let tileCacheBase: String
    public let tiles: [TileRef]
}

public struct PreparedTrip: Codable, Equatable, Sendable {
    public let slug: String
    public let title: String
    public let stats: TourStats
    public let preparedAt: String
    public let bundleUrl: String
}

struct PreparedTripsResponse: Codable, Equatable, Sendable {
    let trips: [PreparedTrip]
}

struct BundleResponse: Codable, Equatable, Sendable {
    let bundle: OfflineBundle
}

public func haversineMeters(
    lon1: Double, lat1: Double,
    lon2: Double, lat2: Double
) -> Double {
    let r = 6_371_000.0
    let rad = Double.pi / 180
    let dLat = (lat2 - lat1) * rad
    let dLon = (lon2 - lon1) * rad
    let h = sin(dLat / 2) * sin(dLat / 2)
        + cos(lat1 * rad) * cos(lat2 * rad) * sin(dLon / 2) * sin(dLon / 2)
    return 2 * r * asin(min(1, sqrt(h)))
}

public func distanceToTrack(lon: Double, lat: Double, track: [[Double]]) -> (meters: Double, nextIndex: Int) {
    guard let first = track.first else { return (0, 0) }
    var best = (meters: Double.infinity, nextIndex: 0)
    for (i, p) in track.enumerated() {
        let d = haversineMeters(lon1: lon, lat1: lat, lon2: p[0], lat2: p[1])
        if d < best.meters { best = (d, i) }
    }
    if best.meters.isInfinite { best = (haversineMeters(lon1: lon, lat1: lat, lon2: first[0], lat2: first[1]), 0) }
    return best
}
