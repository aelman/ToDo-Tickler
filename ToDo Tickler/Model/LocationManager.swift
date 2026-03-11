//
//  LocationManager.swift
//  ToDo Tickler
//

import CoreLocation
import Foundation
import Observation

@Observable
@MainActor
final class LocationManager {

    var currentLocation: CLLocation?
    private var updateTask: Task<Void, Never>?

    func startUpdating() {
        guard updateTask == nil else { return }
        updateTask = Task {
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if !Task.isCancelled {
                        self.currentLocation = update.location
                    }
                }
            } catch {
                // Location updates ended (e.g., authorization revoked or task cancelled)
            }
        }
    }

    func stopUpdating() {
        updateTask?.cancel()
        updateTask = nil
    }

    /// Checks if a TicklerLocation is near the user's current position.
    /// Uses a configurable threshold distance (default 200 meters).
    func isNear(_ ticklerLocation: TicklerLocation, threshold: CLLocationDistance = 200) -> Bool {
        guard let current = currentLocation else { return false }
        let target = CLLocation(
            latitude: ticklerLocation.latitude,
            longitude: ticklerLocation.longitude
        )
        return current.distance(from: target) <= threshold
    }
}
