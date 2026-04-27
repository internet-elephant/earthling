//
//  NewEntryView.swift
//  Earthling
//
//  Created on 3/2/26.
//
//  The new entry sheet. Presented modally over the main window.
//
//  Layout: a narrow metadata column on the left (date, location, sublocation,
//  cancel/save) and a full-height writing area on the right with a toolbar
//  for photo insertion and the markdown reference.
//
//  Photos are staged against a temporary "draft" entry so they can be
//  copied to the correct sandbox path before the entry is saved. If the
//  user discards the entry, staged photos are deleted from disk.
//
//  The body uses a hidden Button to wire up Cmd+/ for the markdown popover,
//  since SwiftUI's .keyboardShortcut can't attach to a non-button view.
//

import SwiftUI
import UniformTypeIdentifiers
import MapKit

struct NewEntryView: View {
    @EnvironmentObject var entryStore: EntryStore
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var date           = Date()
    @State private var city           = ""
    @State private var region         = ""
    @State private var country        = ""
    @State private var latitude:  Double? = nil
    @State private var longitude: Double? = nil
    @State private var entryBody      = ""
    @State private var sublocation    = ""
    @State private var photos:        [EntryPhoto] = []
    @State private var selectedPhotoID: UUID? = nil
    @State private var isDragTargeted = false
    @State private var draggingPhotoID: UUID? = nil
    @State private var showMarkdownHelp = false
    @StateObject private var locationSearch = LocationSearch()
    @State private var showDiscardAlert = false
    @State private var showSublocationWarning = false

    @State private var draftID        = UUID()
    @State private var draftCreatedAt = Date()

    var onSave: ((UUID) -> Void)? = nil

    private let sublocationLimit = 50

    var hasUnsavedContent: Bool {
        !entryBody.isEmpty || !city.isEmpty || !photos.isEmpty
    }

    private var draftEntry: Entry {
        Entry(
            id: draftID,
            date: date,
            city: city.isEmpty ? "_draft" : city,
            region: region,
            country: country.isEmpty ? "_draft" : country,
            continent: ContinentLookup.continent(for: country),
            sublocation: sublocation.isEmpty ? nil : sublocation,
            latitude: latitude,
            longitude: longitude,
            body: entryBody,
            createdAt: draftCreatedAt,
            photos: photos
        )
    }

    // MARK: - Subviews

    private var metadataColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Entry")
                .font(.headline)
                .foregroundColor(themeManager.current.primaryText)

            Divider().background(themeManager.current.sidebarBorder)

            VStack(alignment: .leading, spacing: 4) {
                Text("Date")
                    .font(.caption)
                    .foregroundColor(themeManager.current.secondaryText)
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Place")
                    .font(.caption)
                    .foregroundColor(themeManager.current.secondaryText)
                LocationField(
                    city: $city,
                    region: $region,
                    country: $country,
                    latitude: $latitude,
                    longitude: $longitude,
                    locationSearch: locationSearch
                )
                .environmentObject(themeManager)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sublocation")
                        .font(.caption)
                        .foregroundColor(themeManager.current.secondaryText)
                    Spacer()
                    if !sublocation.isEmpty {
                        Text("\(sublocation.count)/\(sublocationLimit)")
                            .font(.caption)
                            .foregroundColor(
                                sublocation.count >= sublocationLimit
                                    ? .red
                                    : themeManager.current.secondaryText
                            )
                    }
                }

                TextField("neighbourhood, district…", text: $sublocation)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .onChange(of: sublocation) {
                        // Hard cap — prevent typing past the limit
                        if sublocation.count > sublocationLimit {
                            sublocation = String(sublocation.prefix(sublocationLimit))
                        }
                        // Strip characters that are unsafe in filesystem folder names
                        let unsafe = CharacterSet(charactersIn: #"/\:*?"<>|"#)
                        if sublocation.unicodeScalars.contains(where: { unsafe.contains($0) }) {
                            sublocation = sublocation.unicodeScalars
                                .filter { !unsafe.contains($0) }
                                .reduce("") { $0 + String($1) }
                            showSublocationWarning = true
                        } else {
                            showSublocationWarning = false
                        }
                    }

                if showSublocationWarning {
                    Text("Some characters were removed — / \\ : * ? \" < > | are not allowed.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else if sublocation.count >= sublocationLimit {
                    Text("Maximum \(sublocationLimit) characters")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            HStack {
                Button("Cancel") { attemptDismiss() }
                    .foregroundColor(themeManager.current.secondaryText)
                Spacer()
                Button("Save") { saveEntry() }
                    .buttonStyle(.borderedProminent)
                    .disabled(city.isEmpty || entryBody.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 220)
        .background(themeManager.current.sidebarBackground)
    }

    private var writingToolbar: some View {
        HStack {
            Spacer()

            Button(action: pickPhoto) {
                Image(systemName: "photo.badge.plus")
                    .foregroundColor(themeManager.current.secondaryText)
            }
            .buttonStyle(.plain)
            .help("Add photo")
            .padding(.trailing, 8)

            Button(action: { showMarkdownHelp.toggle() }) {
                Text("M↓")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(themeManager.current.secondaryText)
            }
            .buttonStyle(.plain)
            .help("Markdown reference (⌘/)")
            .popover(isPresented: $showMarkdownHelp, arrowEdge: .top) {
                MarkdownCheatSheet()
                    .environmentObject(themeManager)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(themeManager.current.toolbarBackground)
        .overlay(
            Rectangle()
                .fill(themeManager.current.toolbarBorder)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private var photoStrip: some View {
        Group {
            if !photos.isEmpty {
                VStack(spacing: 0) {
                    Divider().background(themeManager.current.sidebarBorder)

                    Text("Photos — drag to reorder")
                        .font(.caption)
                        .foregroundColor(themeManager.current.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .background(themeManager.current.sidebarBackground)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(photos) { photo in
                                EditPhotoThumb(
                                    photo: photo,
                                    entry: draftEntry,
                                    entryStore: entryStore,
                                    isSelected: selectedPhotoID == photo.id,
                                    isDragging: draggingPhotoID == photo.id,
                                    onSelect: {
                                        selectedPhotoID = selectedPhotoID == photo.id
                                            ? nil : photo.id
                                    },
                                    onUpdateAlignment: { updatePhoto(photo.id, alignment: $0) },
                                    onUpdateSize:      { updatePhoto(photo.id, size: $0)      },
                                    onUpdateCaption:   { updatePhoto(photo.id, caption: $0)   },
                                    onDelete:          { removePhoto(photo)                    }
                                )
                                .onDrag {
                                    draggingPhotoID = photo.id
                                    return NSItemProvider(object: photo.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [.plainText],
                                    delegate: PhotoDropDelegate(
                                        targetPhoto: photo,
                                        photos: $photos,
                                        draggingID: $draggingPhotoID
                                    )
                                )
                            }
                        }
                        .padding(12)
                    }
                    .background(themeManager.current.sidebarBackground)
                }
            }
        }
    }

    private var dragTargetZone: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(
                isDragTargeted
                    ? themeManager.current.primaryText
                    : themeManager.current.sidebarBorder,
                style: StrokeStyle(lineWidth: 1.5, dash: [6])
            )
            .frame(height: 44)
            .overlay(
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                    Text("Drag photos here")
                }
                .font(.caption)
                .foregroundColor(themeManager.current.secondaryText)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .background(themeManager.current.mainBackground)
    }

    var body: some View {
        HStack(spacing: 0) {
            metadataColumn

            Rectangle()
                .fill(themeManager.current.sidebarBorder)
                .frame(width: 0.5)

            VStack(spacing: 0) {
                writingToolbar

                TextEditor(text: $entryBody)
                    .font(themeManager.current.bodyFont)
                    .foregroundColor(themeManager.current.primaryText)
                    .scrollContentBackground(.hidden)
                    .background(themeManager.current.mainBackground)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeManager.current.mainBackground)

                photoStrip
                dragTargetZone
            }
        }
        .frame(minWidth: 700, minHeight: 450)
        .onExitCommand { attemptDismiss() }
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .background(
            Button("") { showMarkdownHelp.toggle() }
                .keyboardShortcut("/", modifiers: .command)
                .hidden()
        )
        .confirmationDialog(
                    "Discard this entry?",
                    isPresented: $showDiscardAlert,
                    titleVisibility: .visible
                ) {
                    Button("Discard", role: .destructive) {
                        for photo in photos { entryStore.deletePhoto(photo, from: draftEntry) }
                        dismiss()
                    }
                    Button("Keep Writing", role: .cancel) { }
                } message: {
                    Text("You have unsaved content. Discarding will lose everything you've written.")
                }
                .alert(
                    "Save Failed",
                    isPresented: Binding(
                        get: { entryStore.saveError != nil },
                        set: { if !$0 { entryStore.saveError = nil } }
                    )
                ) {
                    Button("OK") { entryStore.saveError = nil }
                } message: {
                    Text(entryStore.saveError ?? "")
                }
            }

    // MARK: - Photo tag insertion

    private func insertTag(_ tag: String) {
        if let textView = findActiveTextView() {
            let insertIndex = textView.selectedRange().location
            let nsStr       = entryBody as NSString
            if insertIndex <= nsStr.length {
                entryBody = nsStr.replacingCharacters(
                    in: NSRange(location: insertIndex, length: 0), with: tag)
                DispatchQueue.main.async {
                    textView.setSelectedRange(
                        NSRange(location: insertIndex + (tag as NSString).length, length: 0))
                }
                return
            }
        }
        entryBody += tag
    }

    private func findActiveTextView() -> NSTextView? {
        guard let window = NSApplication.shared.keyWindow else { return nil }
        return findTextView(in: window.contentView)
    }

    private func findTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let tv = view as? NSTextView, tv.isEditable { return tv }
        for sub in view.subviews {
            if let found = findTextView(in: sub) { return found }
        }
        return nil
    }

    // MARK: - Photo actions

    private func pickPhoto() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories    = false
        panel.allowedContentTypes     = [.image]
        panel.begin { response in
            guard response == .OK else { return }
            DispatchQueue.main.async {
                let result = entryStore.addPhotos(to: draftEntry, from: panel.urls)
                photos.append(contentsOf: result.photos)
                if !result.tag.isEmpty { insertTag(result.tag) }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data,
                   let url  = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }
            let result = entryStore.addPhotos(to: draftEntry, from: urls)
            photos.append(contentsOf: result.photos)
            if !result.tag.isEmpty { insertTag(result.tag) }
        }
    }

    private func updatePhoto(_ id: UUID, alignment: PhotoAlignment? = nil,
                              size: PhotoSize? = nil, caption: String? = nil) {
        guard let idx = photos.firstIndex(where: { $0.id == id }) else { return }
        if let alignment { photos[idx].alignment = alignment }
        if let size      { photos[idx].size      = size      }
        if let caption   { photos[idx].caption   = caption   }
    }

    private func removePhoto(_ photo: EntryPhoto) {
        entryBody = entryBody
            .replacingOccurrences(of: "\n![photo:\(photo.filename)]\n", with: "\n")
            .replacingOccurrences(of: "![photo:\(photo.filename)]\n", with: "")
            .replacingOccurrences(of: "![photo:\(photo.filename)]",  with: "")

        if let tagRange = entryBody.range(of: #"\!\[gallery:[^\]]*\]"#, options: .regularExpression) {
            let tag       = String(entryBody[tagRange])
            let filenames = tag
                .replacingOccurrences(of: "![gallery:", with: "")
                .replacingOccurrences(of: "]", with: "")
                .components(separatedBy: "|")
                .filter { $0 != photo.filename }
            if filenames.isEmpty {
                entryBody = entryBody.replacingOccurrences(of: tag, with: "")
            } else if filenames.count == 1 {
                entryBody = entryBody.replacingOccurrences(
                    of: tag, with: "![photo:\(filenames[0])]")
            } else {
                entryBody = entryBody.replacingOccurrences(
                    of: tag, with: "![gallery:\(filenames.joined(separator: "|"))]")
            }
        }
        entryStore.deletePhoto(photo, from: draftEntry)
        photos.removeAll { $0.id == photo.id }
    }

    // MARK: - Save / dismiss

    private func attemptDismiss() {
        if hasUnsavedContent {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private func saveEntry() {
        let entry = Entry(
            id: draftID,
            date: date,
            city: city,
            region: region,
            country: country,
            continent: ContinentLookup.continent(for: country),
            sublocation: sublocation.isEmpty ? nil : sublocation,
            latitude: latitude,
            longitude: longitude,
            body: entryBody,
            createdAt: draftCreatedAt,
            photos: photos
        )
        entryStore.save(entry)
        onSave?(entry.id)
        dismiss()
    }
}

// MARK: - Markdown cheat sheet

struct MarkdownCheatSheet: View {
    @EnvironmentObject var themeManager: ThemeManager

    private let items: [(String, String)] = [
        ("# Heading 1",       "Large heading"),
        ("## Heading 2",      "Medium heading"),
        ("### Heading 3",     "Small heading"),
        ("**bold**",          "Bold text"),
        ("*italic*",          "Italic text"),
        ("***bold italic***", "Bold and italic"),
        ("`code`",            "Inline code"),
        ("- item",            "Bullet list"),
        ("1. item",           "Numbered list"),
        ("> quote",           "Blockquote"),
        ("---",               "Horizontal rule"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Markdown Reference")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.current.primaryText)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider().background(themeManager.current.sidebarBorder)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(items, id: \.0) { syntax, description in
                    HStack(spacing: 12) {
                        Text(syntax)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(themeManager.current.primaryText)
                            .frame(width: 130, alignment: .leading)
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.current.secondaryText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)

                    if syntax != items.last?.0 {
                        Divider()
                            .background(themeManager.current.sidebarBorder)
                            .padding(.leading, 14)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .frame(width: 300)
        .background(themeManager.current.sidebarBackground)
    }
}

// MARK: - Location field

struct LocationField: View {
    @Binding var city:      String
    @Binding var region:    String
    @Binding var country:   String
    @Binding var latitude:  Double?
    @Binding var longitude: Double?
    @ObservedObject var locationSearch: LocationSearch
    @EnvironmentObject var themeManager: ThemeManager

    @State private var queryText         = ""
    @State private var hoveredSuggestion: MKLocalSearchCompletion? = nil
    @State private var isSelecting       = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("City or place…", text: $queryText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: queryText) {
                    guard !isSelecting else { return }
                    locationSearch.search(query: queryText)
                }

            if !locationSearch.suggestions.isEmpty && !isSelecting {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(locationSearch.suggestions.prefix(5), id: \.self) { suggestion in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(suggestion.title)
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.current.primaryText)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundColor(themeManager.current.secondaryText)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            hoveredSuggestion == suggestion
                                ? themeManager.current.sidebarBorder
                                : themeManager.current.sidebarBackground
                        )
                        .contentShape(Rectangle())
                        .onHover { isHovered in
                            hoveredSuggestion = isHovered ? suggestion : nil
                        }
                        .onTapGesture {
                            isSelecting = true
                            queryText   = suggestion.title
                            locationSearch.clearSuggestions()
                            locationSearch.select(suggestion)
                        }

                        Divider().background(themeManager.current.sidebarEntryBorder)
                    }
                }
                .background(themeManager.current.sidebarBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(themeManager.current.sidebarBorder, lineWidth: 0.5)
                )
                .cornerRadius(6)
                .shadow(radius: 4)
            }
        }
        .onChange(of: locationSearch.selectedLocation) {
            guard let result = locationSearch.selectedLocation else { return }
            city      = result.city
            region    = result.region
            country   = result.country
            latitude  = result.latitude
            longitude = result.longitude
            queryText = result.city
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSelecting = false
            }
        }
    }
}
