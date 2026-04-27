//
//  Entry.swift
//  Earthling
//
//  Created on 3/2/26.
//
//  Core data models for the app. Entry is the central type — one instance
//  per journal entry, persisted as a Markdown file with YAML frontmatter.
//  EntryPhoto describes an attached image; the image file itself lives on
//  disk and is referenced by filename only.
//

import Foundation

// MARK: - Photo alignment

/// Horizontal position of a photo within the entry body.
enum PhotoAlignment: String, Codable, CaseIterable {
    case left   = "left"
    case center = "center"
    case right  = "right"
}

// MARK: - Photo size

/// Display width of a photo relative to the content column.
enum PhotoSize: String, Codable, CaseIterable {
    case small  = "small"
    case medium = "medium"
    case large  = "large"
    case full   = "full"

    /// Label shown in the size picker during editing.
    var label: String {
        switch self {
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        case .full:   return "Full width"
        }
    }

    /// Fraction of content width — used by legacy layout paths.
    /// Primary sizing uses fixed point values in InlinePhotoView.
    var widthFraction: CGFloat {
        switch self {
        case .small:  return 0.35
        case .medium: return 0.60
        case .large:  return 0.85
        case .full:   return 1.00
        }
    }
}

// MARK: - Photo metadata

/// Metadata for a single attached photo. The image file lives in a
/// subfolder named after the entry's short UUID; use
/// EntryStore.photoURL(for:filename:) to resolve the full path.
///
/// Photos are referenced inline in the entry body via Markdown-style tags:
///   Single photo:  ![photo:filename.jpg]
///   Gallery row:   ![gallery:file1.jpg|file2.jpg]

struct EntryPhoto: Codable, Identifiable, Equatable {
    var id: UUID
    var filename: String
    var alignment: PhotoAlignment
    var size: PhotoSize
    var caption: String?

    init(
        id: UUID = UUID(),
        filename: String,
        alignment: PhotoAlignment = .center,
        size: PhotoSize = .medium,
        caption: String? = nil
    ) {
        self.id        = id
        self.filename  = filename
        self.alignment = alignment
        self.size      = size
        self.caption   = caption
    }
}

// MARK: - Entry

/// A single journal entry. Persisted as a Markdown file with YAML frontmatter
/// under the sandbox Documents directory, organised into folders by
/// continent → country → city → sublocation.
///
/// The file path is derived from date, city, and the first 8 characters of
/// the UUID. GPS coordinates are captured silently via MapKit and stored for
/// the map view — they are not shown directly in the entry UI.

struct Entry: Identifiable, Codable {
    var id: UUID
    /// The date the user assigns to the entry — not necessarily today.
    var date: Date
    var city: String
    var region: String
    var country: String
    /// Auto-assigned via ContinentLookup based on country name.
    var continent: String
    /// Optional freeform sublocation: neighbourhood, district, trail, etc.
    var sublocation: String?
    var latitude: Double?
    var longitude: Double?
    /// Journal text. Supports Markdown, rendered via the Textual package.
    var body: String
    /// Wall-clock save time. Used as a tiebreaker when deduplicating entries.
    var createdAt: Date
    var photos: [EntryPhoto]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        city: String = "",
        region: String = "",
        country: String = "",
        continent: String = "",
        sublocation: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        body: String = "",
        createdAt: Date = Date(),
        photos: [EntryPhoto] = []
    ) {
        self.id          = id
        self.date        = date
        self.city        = city
        self.region      = region
        self.country     = country
        self.continent   = continent
        self.sublocation = sublocation
        self.latitude    = latitude
        self.longitude   = longitude
        self.body        = body
        self.createdAt   = createdAt
        self.photos      = photos
    }
}
