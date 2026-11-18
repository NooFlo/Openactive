#if os(watchOS)
import SwiftUI

struct BacktrackView: View {
    // Skeleton data: real routes arrive from the phone via Watch Connectivity (docs/ARCHITECTURE.md §7).
    // CoreLocation + HealthKit workout session (background GPS) are the next step.
    private let route: [[Double]] = [
        [11.4020, 47.2710], [11.4035, 47.2742], [11.4061, 47.2768], [11.4098, 47.2781],
        [11.4140, 47.2786], [11.4182, 47.2772], [11.4205, 47.2744], [11.4210, 47.2712],
        [11.4192, 47.2684], [11.4151, 47.2670], [11.4104, 47.2668], [11.4062, 47.2681],
        [11.4030, 47.2696],
    ]
    private let current = [11.4192, 47.2684]
    private let headingDegrees: Double = 205

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 6) {
                BreadcrumbCanvas(route: route, current: current, headingDegrees: headingDegrees)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: 2) {
                    Text("next waypoint")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Text(nextWaypointText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.green)
                    Text(offRouteText)
                        .font(.caption2)
                        .foregroundStyle(offRouteText == "on route" ? .gray : .orange)
                }
            }
        }
    }

    private var nextWaypointText: String {
        let nearest = distanceToTrack(lon: current[0], lat: current[1], track: route)
        let nextIdx = min(nearest.nextIndex + 1, route.count - 1)
        let next = route[nextIdx]
        let meters = haversineMeters(
            lon1: current[0], lat1: current[1],
            lon2: next[0], lat2: next[1]
        )
        if meters >= 1000 { return String(format: "%.1f km", meters / 1000) }
        return String(format: "%.0f m", meters)
    }

    private var offRouteText: String {
        let d = distanceToTrack(lon: current[0], lat: current[1], track: route).meters
        if d < 30 { return "on route" }
        return String(format: "%.0f m off route", d)
    }
}

private struct BreadcrumbCanvas: View {
    let route: [[Double]]
    let current: [Double]
    let headingDegrees: Double

    var body: some View {
        Canvas { context, size in
            guard route.count > 1,
                  let projection = Projection(track: route + [current], size: size)
            else { return }

            var path = Path()
            path.move(to: projection.point(lon: route[0][0], lat: route[0][1]))
            for p in route.dropFirst() {
                path.addLine(to: projection.point(lon: p[0], lat: p[1]))
            }
            context.stroke(path, with: .color(.green), lineWidth: 2.5)

            let here = projection.point(lon: current[0], lat: current[1])
            drawHeadingCone(context: context, at: here, headingDegrees: headingDegrees)

            context.fill(Path(ellipseIn: CGRect(x: here.x - 4, y: here.y - 4, width: 8, height: 8)), with: .color(.red))
        }
    }

    private func drawHeadingCone(context: GraphicsContext, at center: CGPoint, headingDegrees: Double) {
        let radius: CGFloat = 26
        let heading = Angle.degrees(headingDegrees - 90)
        let halfAngle = Angle.degrees(35)
        var cone = Path()
        cone.move(to: center)
        cone.addArc(center: center, radius: radius, startAngle: heading - halfAngle, endAngle: heading + halfAngle, clockwise: false)
        cone.closeSubpath()
        context.fill(cone, with: .color(.red.opacity(0.28)))
        context.stroke(cone, with: .color(.red.opacity(0.8)), lineWidth: 1)
    }
}

private struct Projection {
    let scale: Double
    let minLon: Double
    let maxLat: Double
    let size: CGSize

    init?(track: [[Double]], size: CGSize) {
        guard track.count >= 2,
              size.width > 0, size.height > 0,
              let minLon = track.map(\.first).compactMap({ $0 }).min(),
              let maxLon = track.map(\.first).compactMap({ $0 }).max(),
              let minLat = track.map { $0.count > 1 ? $0[1] : nil }.compactMap({ $0 }).min(),
              let maxLat = track.map { $0.count > 1 ? $0[1] : nil }.compactMap({ $0 }).max(),
              maxLon > minLon || maxLat > minLat
        else { return nil }
        self.minLon = minLon
        self.maxLat = maxLat
        self.size = size
        let padding: Double = 0.82
        let scaleX = size.width * padding / max(maxLon - minLon, 1e-9)
        let scaleY = size.height * padding / max(maxLat - minLat, 1e-9)
        self.scale = min(scaleX, scaleY)
    }

    func point(lon: Double, lat: Double) -> CGPoint {
        let w = Double(size.width), h = Double(size.height)
        let x = w / 2 + (lon - minLon) * scale
        let y = h / 2 + (maxLat - lat) * scale
        return CGPoint(x: x, y: y)
    }
}
#endif
