import SwiftUI
import MapKit
import OpenactiveCore

struct TourMapScreen: View {
    @EnvironmentObject private var state: AppState
    @State private var selectedSlug: String?

    var body: some View {
        let bundles = state.downloadedBundles
        let selection = firstValid(bundles, preferred: selectedSlug)
        Group {
            if bundles.isEmpty {
                ContentUnavailableView(
                    "Nothing downloaded",
                    systemImage: "map",
                    description: Text("Download a prepared trip on the Trips tab to see it on the map — works fully offline.")
                )
            } else if let bundle = selection.bundle {
                VStack(spacing: 0) {
                    Picker("Trip", selection: Binding(
                        get: { selectedSlug ?? bundle.slug },
                        set: { selectedSlug = $0 }
                    )) {
                        ForEach(bundles, id: \.slug) { b in
                            Text(b.title).tag(b.slug as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(6)
                    if let coords = coordinates(for: bundle), !coords.isEmpty {
                        TrackMap(coords: coords)
                    } else {
                        Text("This trip has no track points")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Offline map")
        .onAppear { selectedSlug = selection.slug }
    }

    private func firstValid(_ bundles: [OfflineBundle], preferred: String?) -> (slug: String?, bundle: OfflineBundle?) {
        if let preferred, let match = bundles.first(where: { $0.slug == preferred }) {
            return (preferred, match)
        }
        return (bundles.first?.slug, bundles.first)
    }

    private func coordinates(for bundle: OfflineBundle) -> [CLLocationCoordinate2D]? {
        let pts = bundle.points
        guard pts.allSatisfy({ $0.count >= 2 }) else { return nil }
        return pts.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
    }
}

struct TrackMap: View {
    let coords: [CLLocationCoordinate2D]
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            MapPolyline(coordinates: coords)
                .stroke(.red, lineWidth: 4)
        }
        .mapStyle(.standard(elevation: .realistic))
        .onAppear {
            position = .region(fittingRegion())
        }
        .allowsHitTesting(true)
    }

    private func fittingRegion() -> MKCoordinateRegion {
        var minLat = coords[0].latitude, maxLat = minLat
        var minLon = coords[0].longitude, maxLon = minLon
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            latitudinalMeters: spanMeters(minLat, maxLat),
            longitudinalMeters: spanMeters(minLon, maxLon)
        )
    }

    private func spanMeters(_ a: Double, _ b: Double) -> Double {
        max(haversineMeters(lon1: 0, lat1: a, lon2: 0, lat2: b), 800) * 1.4
    }
}
