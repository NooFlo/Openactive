import SwiftUI
import OpenactiveCore

struct TripsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationStack {
            Group {
                if !state.isSignedIn {
                    ContentUnavailableView("Not signed in", systemImage: "person.crop.circle", description: Text("Sign in on the Settings tab to list prepared trips from your home server."))
                } else if state.trips.isEmpty {
                    ContentUnavailableView("No prepared trips", systemImage: "map", description: Text("Ingest a tour on the web map and hit “Prepare trip for mobile”"))
                } else {
                    List(state.trips, id: \.slug) { trip in
                        TripRow(trip: trip)
                    }
                    .refreshable { await state.refreshTrips() }
                }
            }
            .navigationTitle("Prepared trips")
            .task { await state.refreshTrips() }
        }
    }

    private struct TripRow: View {
        @EnvironmentObject private var state: AppState
        let trip: PreparedTrip

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.title).font(.headline)
                    Text(statsLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                trailing
            }
        }

        @ViewBuilder
        private var trailing: some View {
            if let progress = state.downloadProgress, progress.slug == trip.slug {
                VStack {
                    ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
                        .frame(width: 90)
                    Text("\(progress.done)/\(progress.total)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if state.isDownloaded(trip) {
                Label("On device", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
                    .font(.footnote)
            } else {
                Button("Download") { Task { await state.download(trip: trip) } }
                    .buttonStyle(.bordered)
                    .disabled(state.isBusy)
            }
        }

        private var statsLine: String {
            let s = trip.stats
            var parts = [String(format: "%.1f km · %d pts", s.distanceKm, s.points)]
            parts.append("↑\(Int(s.ascentM)) m ↓\(Int(s.descentM)) m")
            let date = trip.preparedAt.prefix(10)
            parts.append("prepared \(date)")
            return parts.joined(separator: " · ")
        }
    }
}
