//
//  EntryStore.swift
//  Earthling
//
//  Created on 3/2/26.
//
//  The persistence layer. Handles reading and writing entries as Markdown
//  files with YAML frontmatter, organised into a folder hierarchy under
//  the app's sandbox Documents directory:
//
//    Earthling/
//      {Continent}/
//        {Country}/
//          {City}/
//            {date}-{city}-{shortID}.md
//            {shortID}/               ← photo subfolder
//              {date}-{city}-{name}.jpg
//
//  EntryStore is an ObservableObject so SwiftUI views re-render whenever
//  the entries array changes. All mutations (save, delete) call loadEntries()
//  at the end to keep the published array in sync with disk.
//

import Foundation
import Combine

class EntryStore: ObservableObject {

    @Published var entries:   [Entry] = []
    /// Set to a human-readable message when a save fails. Views can observe
    /// this to show an alert so the user knows their entry was not written.
    @Published var saveError: String? = nil

    private let fileManager = FileManager.default

    /// Root of the Earthling file hierarchy within the sandbox Documents folder.
    private var rootURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Earthling")
    }

    init() {
        loadEntries()
    }

    // MARK: - Path helpers

    /// Folder containing the entry's .md file and photo subfolder.
    private func folderURL(for entry: Entry) -> URL {
        var url = rootURL
            .appendingPathComponent(sanitizeFolderName(entry.continent))
            .appendingPathComponent(sanitizeFolderName(entry.country))
            .appendingPathComponent(cleanName(entry.city))
        if let sub = entry.sublocation, !sub.isEmpty {
            url = url.appendingPathComponent(cleanName(sub))
        }
        return url
    }

    /// Full path to the entry's .md file.
    private func fileURL(for entry: Entry) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: entry.date)
        let cityClean  = cleanName(entry.city)
        let shortID    = String(entry.id.uuidString.prefix(8))
        return folderURL(for: entry)
            .appendingPathComponent("\(dateString)-\(cityClean)-\(shortID).md")
    }

    /// Folder that holds this entry's photo files, named after the entry's short UUID.
    func photoFolderURL(for entry: Entry) -> URL {
        let shortID = String(entry.id.uuidString.prefix(8))
        return folderURL(for: entry).appendingPathComponent(shortID)
    }

    /// Full path to a specific photo file within the entry's photo folder.
    /// Validates that the resolved path stays within the photo folder to
    /// prevent any path traversal via a malformed filename.
    func photoURL(for entry: Entry, filename: String) -> URL {
        let folder   = photoFolderURL(for: entry)
        let resolved = folder.appendingPathComponent(filename)
        // Ensure the resolved path is still inside the photo folder.
        guard resolved.path.hasPrefix(folder.path) else {
            return folder.appendingPathComponent("invalid")
        }
        return resolved
    }

    /// Strips characters unsafe in file and folder names, and removes newlines
    /// that would corrupt the YAML frontmatter format.
    /// Handles the full set of problematic characters: / \ : * ? " < > |
    private func cleanName(_ name: String) -> String {
        let unsafe = CharacterSet(charactersIn: #"/\:*?"<>|"#)
            .union(.newlines)
        return name
            .unicodeScalars
            .filter { !unsafe.contains($0) }
            .reduce("") { $0 + String($1) }
            .replacingOccurrences(of: " ", with: "-")
    }

    /// Sanitizes continent and country names from ContinentLookup/MapKit.
    /// These are trusted sources but we strip newlines defensively.
    private func sanitizeFolderName(_ name: String) -> String {
        name
            .components(separatedBy: .newlines).joined()
            .replacingOccurrences(of: "/", with: "-")
    }

    // MARK: - Save

    /// Saves an entry to disk. Sets `saveError` if writing fails so the UI
    /// can alert the user rather than silently losing their content.
    func save(_ entry: Entry) {
        do {
            let folder = folderURL(for: entry)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let content = markdownContent(for: entry)
            try content.write(to: fileURL(for: entry), atomically: true, encoding: .utf8)
            saveError = nil
        } catch {
            saveError = "Your entry could not be saved: \(error.localizedDescription)"
        }
        loadEntries()
    }

    // MARK: - Delete

    func delete(_ entry: Entry) {
        try? fileManager.removeItem(at: fileURL(for: entry))

        // Remove the photo subfolder if it exists.
        let photoFolder = photoFolderURL(for: entry)
        if fileManager.fileExists(atPath: photoFolder.path) {
            try? fileManager.removeItem(at: photoFolder)
        }

        // Walk up the folder hierarchy and remove any directories that are
        // now empty, stopping at the Earthling root. This cleans up sublocation,
        // city, country, and continent folders when their last entry is deleted.
        var folder = folderURL(for: entry)
        while folder.path != rootURL.path {
            let contents = (try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? []
            if contents.isEmpty {
                try? fileManager.removeItem(at: folder)
            } else {
                break
            }
            folder = folder.deletingLastPathComponent()
        }

        loadEntries()
    }

    // MARK: - Photos

    /// Copies a single photo into the entry's photo folder.
    /// Returns the EntryPhoto metadata, or nil if the copy fails.
    func addPhoto(to entry: Entry, from sourceURL: URL) -> EntryPhoto? {
        copyPhoto(to: entry, from: sourceURL)
    }

    /// Copies one or more photos and returns both the metadata array and
    /// the inline body tag to insert at the cursor:
    ///   1 photo  → `![photo:filename]`
    ///   2+ photos → `![gallery:file1|file2|...]`
    func addPhotos(to entry: Entry, from sourceURLs: [URL]) -> (photos: [EntryPhoto], tag: String) {
        let added = sourceURLs.compactMap { copyPhoto(to: entry, from: $0) }
        guard !added.isEmpty else { return ([], "") }

        let tag: String
        if added.count == 1 {
            tag = "\n![photo:\(added[0].filename)]\n"
        } else {
            let filenames = added.map { $0.filename }.joined(separator: "|")
            tag = "\n![gallery:\(filenames)]\n"
        }
        return (added, tag)
    }

    /// Copies a photo file from sourceURL into the entry's photo folder.
    /// Appends a short UUID to the filename if a file with the same name
    /// already exists, to avoid silent overwrites.
    private func copyPhoto(to entry: Entry, from sourceURL: URL) -> EntryPhoto? {
        let photoFolder = photoFolderURL(for: entry)
        do {
            try fileManager.createDirectory(at: photoFolder, withIntermediateDirectories: true)
        } catch { return nil }

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let dateStr       = dateFmt.string(from: entry.date)
        let cityClean     = cleanName(entry.city.isEmpty ? "draft" : entry.city)
        let ext           = sourceURL.pathExtension.lowercased()
        let originalName  = sourceURL.deletingPathExtension().lastPathComponent
        let cleanOriginal = cleanName(originalName)
        let photoID       = UUID()
        let shortPhotoID  = String(photoID.uuidString.prefix(8))
        let filename      = "\(dateStr)-\(cityClean)-\(cleanOriginal).\(ext.isEmpty ? "jpg" : ext)"
        let destURL       = photoFolder.appendingPathComponent(filename)

        // Security-scoped access is required for URLs obtained via drag-and-drop.
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        do {
            if fileManager.fileExists(atPath: destURL.path) {
                let uniqueFilename = "\(dateStr)-\(cityClean)-\(cleanOriginal)-\(shortPhotoID).\(ext.isEmpty ? "jpg" : ext)"
                let uniqueDestURL  = photoFolder.appendingPathComponent(uniqueFilename)
                try fileManager.copyItem(at: sourceURL, to: uniqueDestURL)
                return EntryPhoto(id: photoID, filename: uniqueFilename)
            } else {
                try fileManager.copyItem(at: sourceURL, to: destURL)
                return EntryPhoto(id: photoID, filename: filename)
            }
        } catch { return nil }
    }

    /// Removes a photo file from disk. Does not update the entry's photos
    /// array — callers are responsible for that.
    func deletePhoto(_ photo: EntryPhoto, from entry: Entry) {
        let url = photoURL(for: entry, filename: photo.filename)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Load

    /// Scans the entire Earthling folder tree, parses every .md file found,
    /// deduplicates by UUID (keeping the most recently created copy), and
    /// publishes the result sorted newest-date first.
    ///
    /// Parsing runs on a background thread to avoid blocking the main thread
    /// for large entries. Results are published back on main.
    func loadEntries() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            var loaded: [Entry] = []

            guard let enumerator = self.fileManager.enumerator(
                at: self.rootURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                DispatchQueue.main.async { self.entries = [] }
                return
            }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "md" else { continue }
                if let entry = self.parseEntry(from: fileURL) {
                    loaded.append(entry)
                }
            }

            // Deduplicate by UUID — keeps the newest createdAt if duplicates exist.
            var seen = [UUID: Entry]()
            for entry in loaded {
                if let existing = seen[entry.id] {
                    seen[entry.id] = entry.createdAt > existing.createdAt ? entry : existing
                } else {
                    seen[entry.id] = entry
                }
            }

            let sorted = Array(seen.values).sorted { $0.date > $1.date }

            DispatchQueue.main.async {
                self.entries = sorted
            }
        }
    }
    // MARK: - Markdown formatting

    /// Serialises an entry to a Markdown string with YAML frontmatter.
    /// The photos array is encoded as a compact JSON blob on a single line
    /// so it survives the line-by-line frontmatter parser on read.
    private func markdownContent(for entry: Entry) -> String {
        // Strip newlines from frontmatter string values to prevent
        // corrupting the YAML structure on read.
        func safeFM(_ value: String) -> String {
            value.components(separatedBy: .newlines).joined()
        }

        var fm = "---\n"
        fm += "id: \(entry.id.uuidString)\n"
        fm += "date: \(ISO8601DateFormatter().string(from: entry.date))\n"
        fm += "city: \(safeFM(entry.city))\n"
        fm += "region: \(safeFM(entry.region))\n"
        fm += "country: \(safeFM(entry.country))\n"
        fm += "continent: \(safeFM(entry.continent))\n"

        if let sub = entry.sublocation, !sub.isEmpty {
            fm += "sublocation: \(safeFM(sub))\n"
        }
        if let lat = entry.latitude  { fm += "latitude: \(lat)\n"  }
        if let lon = entry.longitude { fm += "longitude: \(lon)\n" }

        fm += "createdAt: \(ISO8601DateFormatter().string(from: entry.createdAt))\n"

        if !entry.photos.isEmpty,
           let photosData   = try? JSONEncoder().encode(entry.photos),
           let photosString = String(data: photosData, encoding: .utf8) {
            fm += "photos: \(photosString)\n"
        }

        fm += "---\n\n"
        fm += entry.body
        return fm
    }

    // MARK: - Markdown parsing

    /// Parses a .md file into an Entry. Returns nil if the file is missing
    /// required frontmatter fields (city, country).
    ///
    /// The frontmatter splitter uses `\n---\n` as the delimiter, which means
    /// the opening `---` on line 1 must be followed immediately by a newline.
    /// Body text containing `---` on its own line is preserved correctly
    /// because parts[1...] is rejoined with the delimiter.
    private func parseEntry(from url: URL) -> Entry? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let parts = content.components(separatedBy: "\n---\n")
        guard parts.count >= 2 else { return nil }

        let frontmatterRaw = parts[0].replacingOccurrences(of: "---\n", with: "")
        var frontmatter: [String: String] = [:]

        for line in frontmatterRaw.components(separatedBy: "\n") {
            // maxSplits:1 preserves colons inside values (ISO dates, JSON).
            let kv = line.split(separator: ":", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if kv.count == 2 { frontmatter[kv[0]] = kv[1] }
        }

        let body = parts[1...].joined(separator: "\n---\n")
            .trimmingCharacters(in: .init(charactersIn: "\n"))

        guard
            let city    = frontmatter["city"],
            let country = frontmatter["country"]
        else { return nil }

        let id        = UUID(uuidString: frontmatter["id"] ?? "") ?? UUID()
        let date      = ISO8601DateFormatter().date(from: frontmatter["date"] ?? "") ?? Date()
        let createdAt = ISO8601DateFormatter().date(from: frontmatter["createdAt"] ?? "") ?? Date()

        var photos: [EntryPhoto] = []
        if let photosString = frontmatter["photos"],
           let photosData   = photosString.data(using: .utf8) {
            photos = (try? JSONDecoder().decode([EntryPhoto].self, from: photosData)) ?? []
        }

        return Entry(
            id:          id,
            date:        date,
            city:        city,
            region:      frontmatter["region"]    ?? "",
            country:     country,
            continent:   frontmatter["continent"] ?? ContinentLookup.continent(for: country),
            sublocation: frontmatter["sublocation"],
            latitude:    Double(frontmatter["latitude"]  ?? ""),
            longitude:   Double(frontmatter["longitude"] ?? ""),
            body:        body,
            createdAt:   createdAt,
            photos:      photos
        )
    }
}
