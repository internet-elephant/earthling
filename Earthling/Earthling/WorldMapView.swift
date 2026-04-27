//
//  WorldMapView.swift
//  Earthling
//
//  Created on 3/31/26.
//
//  Displays a MapKit world map with a pin for each city that has at least
//  one journal entry. Cities with multiple entries show a count badge.
//  Tapping a pin's callout opens the most recent entry for that city.
//
//  ScrollableMapView subclasses MKMapView to add Magic Mouse / trackpad
//  scroll-wheel zoom, which MapKit doesn't provide out of the box on macOS.
//
//  Entries without GPS coordinates are silently skipped — coordinates are
//  captured via MapKit autocomplete when an entry is created.
//

import SwiftUI
import MapKit

// MARK: - City annotation

class CityAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let city: String
    var entryIDs: [UUID]

    var title: String? { city }
    var subtitle: String? {
        entryIDs.count == 1 ? "1 entry" : "\(entryIDs.count) entries"
    }

    init(city: String, coordinate: CLLocationCoordinate2D, entryIDs: [UUID]) {
        self.city       = city
        self.coordinate = coordinate
        self.entryIDs   = entryIDs
    }
}

// MARK: - Scroll-to-zoom map view

class ScrollableMapView: MKMapView {
    override func scrollWheel(with event: NSEvent) {
        guard event.deltaY != 0 else { return }
        let zoomFactor: Double = event.deltaY > 0 ? 0.85 : 1.15
        var region = self.region
        let newLat = region.span.latitudeDelta  * zoomFactor
        let newLon = region.span.longitudeDelta * zoomFactor
        guard newLat >= 0.01, newLat <= 170 else { return }
        guard newLon >= 0.01, newLon <= 360 else { return }
        region.span.latitudeDelta  = newLat
        region.span.longitudeDelta = newLon
        setRegion(region, animated: false)
    }
}

// MARK: - Map view

struct WorldMapView: NSViewRepresentable {
    let entries: [Entry]
    var onSelectEntry: (UUID) -> Void

    /// Groups entries by city name, combining IDs for cities with multiple entries.
    private var cityAnnotations: [CityAnnotation] {
        var groups: [String: (CLLocationCoordinate2D, [UUID])] = [:]
        for entry in entries {
            guard let lat = entry.latitude, let lon = entry.longitude else { continue }
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            if var existing = groups[entry.city] {
                existing.1.append(entry.id)
                groups[entry.city] = existing
            } else {
                groups[entry.city] = (coord, [entry.id])
            }
        }
        return groups.map { city, value in
            CityAnnotation(city: city, coordinate: value.0, entryIDs: value.1)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectEntry: onSelectEntry)
    }

    func makeNSView(context: Context) -> ScrollableMapView {
        let mapView = ScrollableMapView()
        mapView.delegate        = context.coordinator
        mapView.showsCompass    = true
        mapView.showsScale      = true
        mapView.isZoomEnabled   = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled  = false

        // Open at world scale centered slightly north to favour land mass.
        mapView.setCamera(MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: 20, longitude: 10),
            fromDistance: 20_000_000, pitch: 0, heading: 0
        ), animated: false)

        return mapView
    }

    func updateNSView(_ mapView: ScrollableMapView, context: Context) {
        context.coordinator.onSelectEntry = onSelectEntry

        // Only refresh annotations when the set of cities actually changes.
        let newAnnotations = cityAnnotations
        let newCities      = Set(newAnnotations.map { $0.city })
        let existingCities = Set(mapView.annotations
            .compactMap { $0 as? CityAnnotation }
            .map { $0.city })
        guard newCities != existingCities else { return }

        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotations(newAnnotations)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var onSelectEntry: (UUID) -> Void

        init(onSelectEntry: @escaping (UUID) -> Void) {
            self.onSelectEntry = onSelectEntry
        }

        func mapView(_ mapView: MKMapView,
                     viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let city = annotation as? CityAnnotation else { return nil }

            let id   = "CityPin"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id)
                        as? MKMarkerAnnotationView)
                       ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)

            view.annotation      = annotation
            view.canShowCallout  = true
            view.markerTintColor = NSColor(red: 0.42, green: 0.40, blue: 0.75, alpha: 1)

            if city.entryIDs.count > 1 {
                view.glyphText  = "\(city.entryIDs.count)"
            } else {
                view.glyphImage = NSImage(systemSymbolName: "mappin",
                                          accessibilityDescription: nil)
            }

            let btn = NSButton(frame: NSRect(x: 0, y: 0, width: 54, height: 24))
            btn.title      = "Open"
            btn.bezelStyle = .rounded
            btn.target     = self
            btn.action     = #selector(openTapped(_:))
            view.rightCalloutAccessoryView = btn

            return view
        }

        /// Handles the Open button tap by walking the view hierarchy to find
        /// the annotation, then calling onSelectEntry with the first entry ID.
        @objc func openTapped(_ sender: NSButton) {
            var v = sender.superview
            while v != nil {
                if let av  = v as? MKMarkerAnnotationView,
                   let ann = av.annotation as? CityAnnotation,
                   let id  = ann.entryIDs.first {
                    onSelectEntry(id)
                    return
                }
                v = v?.superview
            }
        }

        func mapView(_ mapView: MKMapView,
                     annotationView view: MKAnnotationView,
                     calloutAccessoryControlClicked control: NSControl) {
            guard let ann = view.annotation as? CityAnnotation,
                  let id  = ann.entryIDs.first else { return }
            onSelectEntry(id)
        }
    }
}
