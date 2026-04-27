//
//  LocationSearch.swift
//  Earthling
//
//  Created on 3/2/26.
//
//  Wraps MapKit's MKLocalSearchCompleter to provide city autocomplete
//  and coordinate lookup. LocationSearch is used as a @StateObject in
//  NewEntryView — one instance per new entry form.
//
//  The flow: user types → search() feeds the completer → suggestions
//  publishes completion results → user taps one → select() resolves it
//  to a full placemark with coordinates → selectedLocation publishes
//  the result for the form to consume.
//

import Foundation
import MapKit
import Combine

class LocationSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {

    /// Live autocomplete suggestions, updated as the user types.
    @Published var suggestions: [MKLocalSearchCompletion] = []

    /// Set when the user selects a suggestion. Observed by LocationField
    /// to populate city, region, country, and coordinates.
    @Published var selectedLocation: LocationResult? = nil

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    // MARK: - Search

    /// Feed a query string to the completer. Clears suggestions on empty input.
    func search(query: String) {
        guard !query.isEmpty else {
            suggestions = []
            return
        }
        completer.queryFragment = query
    }

    func clearSuggestions() {
        suggestions = []
    }

    // MARK: - Selection

    /// Resolves a completion to a full placemark via MKLocalSearch,
    /// then publishes the result as a LocationResult.
    func select(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search  = MKLocalSearch(request: request)

        search.start { [weak self] response, _ in
            guard let item = response?.mapItems.first else { return }
            let placemark = item.placemark
            let country   = placemark.country ?? ""

            DispatchQueue.main.async {
                self?.selectedLocation = LocationResult(
                    city:      placemark.locality ?? placemark.name ?? "",
                    region:    placemark.administrativeArea ?? "",
                    country:   country,
                    continent: ContinentLookup.continent(for: country),
                    latitude:  placemark.coordinate.latitude,
                    longitude: placemark.coordinate.longitude
                )
                self?.clearSuggestions()
            }
        }
    }

    // MARK: - MKLocalSearchCompleterDelegate

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.suggestions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Silently clear suggestions on failure — the user can keep typing.
        suggestions = []
    }
}

// MARK: - LocationResult

/// A resolved location with all fields needed to populate an entry.
/// Equatable so LocationField can detect when selectedLocation changes.
struct LocationResult: Equatable {
    var city: String
    var region: String
    var country: String
    var continent: String
    var latitude: Double
    var longitude: Double
}
