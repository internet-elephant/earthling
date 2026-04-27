//
//  EntryDetailView.swift
//  Earthling
//
//  Created on 3/2/26.
//
//  The main reading and editing view for a single journal entry.
//  Displayed in the right panel of the main window when an entry is selected.
//
//  Two modes:
//    Read — renders Markdown body and inline photos via InlineEntryBody.
//    Edit — shows a TextEditor, photo strip with drag-to-reorder, and a
//           dashed drop zone for adding new photos.
//
//  The view reads live from EntryStore using entryID so it always shows
//  the latest saved state after an edit.
//

import SwiftUI
import Textual
import UniformTypeIdentifiers
import AppKit

struct EntryDetailView: View {
    let entryID: UUID
    /// Called when edit mode starts or ends so ContentView can guard
    /// actions like New Entry and Toggle Map while editing is active.
    var onEditingChanged: ((Bool) -> Void)? = nil

    @EnvironmentObject var entryStore: EntryStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showDeleteConfirm  = false
    @State private var isEditing          = false
    @State private var editedBody         = ""
    @State private var editedPhotos: [EntryPhoto] = []
    @State private var showDiscardAlert   = false
    @State private var isDragTargeted     = false
    @State private var selectedPhotoID: UUID? = nil
    @State private var draggingPhotoID: UUID? = nil
    @State private var showMarkdownHelp   = false
    @FocusState private var editorFocused: Bool

    private var entry: Entry? {
        entryStore.entries.first { $0.id == entryID }
    }

    private var hasUnsavedChanges: Bool {
        editedBody   != (entry?.body   ?? "") ||
        editedPhotos != (entry?.photos ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Toolbar
            HStack {
                Spacer()
                if isEditing {
                    Button(action: pickPhoto) {
                        Image(systemName: "photo.badge.plus")
                            .foregroundColor(themeManager.current.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help("Add photo")
                    .padding(.trailing, 8)

                    Button("Cancel") { attemptDiscardEdit() }
                        .foregroundColor(themeManager.current.secondaryText)
                        .padding(.trailing, 8)

                    // Custom style keeps the button fully visible even when
                    // the window loses focus — .borderedProminent dims with
                    // the system accent color when the window is not key.
                    Button("Save") {
                        saveEdit(body: editedBody, photos: editedPhotos)
                        isEditing = false
                        onEditingChanged?(false)
                    }
                    .buttonStyle(SteadySaveButtonStyle())
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
                } else {
                    Button(action: {
                        editedBody    = entry?.body   ?? ""
                        editedPhotos  = entry?.photos ?? []
                        isEditing     = true
                        editorFocused = true
                        onEditingChanged?(true)
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(themeManager.current.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .disabled(entry == nil)

                    Button(role: .destructive, action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(themeManager.current.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                    .disabled(entry == nil)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(themeManager.current.toolbarBackground)
            .overlay(
                Rectangle()
                    .fill(themeManager.current.toolbarBorder)
                    .frame(height: 0.5),
                alignment: .bottom
            )

            // MARK: Content
            if let entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.date, style: .date)
                            .font(.caption)
                            .foregroundColor(themeManager.current.secondaryText)

                        Text(entry.city)
                            .font(themeManager.current.titleFont)
                            .foregroundColor(themeManager.current.primaryText)

                        if !entry.country.isEmpty {
                            Text([entry.region, entry.country]
                                .filter { !$0.isEmpty }
                                .joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundColor(themeManager.current.secondaryText)
                        }

                        if let sub = entry.sublocation, !sub.isEmpty {
                            Text(sub)
                                .font(.subheadline)
                                .foregroundColor(themeManager.current.secondaryText)
                        }

                        Divider()
                            .background(themeManager.current.sidebarBorder)
                            .padding(.vertical, 4)

                        if isEditing {
                            VStack(alignment: .leading, spacing: 16) {
                                TextEditor(text: $editedBody)
                                    .font(themeManager.current.bodyFont)
                                    .foregroundColor(themeManager.current.primaryText)
                                    .scrollContentBackground(.hidden)
                                    .background(themeManager.current.mainBackground)
                                    .focused($editorFocused)
                                    .frame(minHeight: 300)
                                    .onExitCommand { attemptDiscardEdit() }

                                if !editedPhotos.isEmpty {
                                    Divider()
                                        .background(themeManager.current.sidebarBorder)

                                    Text("Photos — drag to reorder")
                                        .font(.caption)
                                        .foregroundColor(themeManager.current.secondaryText)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(editedPhotos) { photo in
                                                EditPhotoThumb(
                                                    photo: photo,
                                                    entry: entry,
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
                                                    onDelete:          { removePhoto(photo, from: entry)      }
                                                )
                                                .onDrag {
                                                    draggingPhotoID = photo.id
                                                    return NSItemProvider(object: photo.id.uuidString as NSString)
                                                }
                                                .onDrop(
                                                    of: [.plainText],
                                                    delegate: PhotoDropDelegate(
                                                        targetPhoto: photo,
                                                        photos: $editedPhotos,
                                                        draggingID: $draggingPhotoID
                                                    )
                                                )
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }

                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        isDragTargeted
                                            ? themeManager.current.primaryText
                                            : themeManager.current.sidebarBorder,
                                        style: StrokeStyle(lineWidth: 1.5, dash: [6])
                                    )
                                    .frame(height: 60)
                                    .overlay(
                                        HStack(spacing: 6) {
                                            Image(systemName: "photo")
                                            Text("Drag photos here")
                                        }
                                        .font(.caption)
                                        .foregroundColor(themeManager.current.secondaryText)
                                    )
                            }
                        } else {
                            InlineEntryBody(
                                entry: entry,
                                entryStore: entryStore,
                                themeManager: themeManager
                            )
                        }
                    }
                    .padding(24)
                }
                .background(themeManager.current.mainBackground)
                .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
                    guard isEditing else { return false }
                    handleDrop(providers: providers, entry: entry)
                    return true
                }
            } else {
                ZStack {
                    themeManager.current.mainBackground.ignoresSafeArea()
                    Text("Entry not found")
                        .foregroundColor(themeManager.current.secondaryText)
                }
            }
        }
        .background(themeManager.current.mainBackground)
        .background(
            Button("") { showMarkdownHelp.toggle() }
                .keyboardShortcut("/", modifiers: .command)
                .hidden()
        )
        // Whenever the photo strip is reordered via drag-and-drop, rebuild
        // any gallery tags in the body to match the new sequence. Without
        // this the tag filenames stay in their original insertion order even
        // though the thumbnail strip has been rearranged.
        .onChange(of: editedPhotos) { syncGalleryTagOrder() }
        .confirmationDialog(
                    "Discard changes?",
                    isPresented: $showDiscardAlert,
                    titleVisibility: .visible
                ) {
                    Button("Discard", role: .destructive) {
                        isEditing    = false
                        editedBody   = ""
                        editedPhotos = []
                        onEditingChanged?(false)
                    }
                    Button("Keep Editing", role: .cancel) { }
                } message: {
                    Text("You have unsaved changes. Discarding will lose everything you've edited.")
                }
                .confirmationDialog(
                    "Delete this entry?",
                    isPresented: $showDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        if let entry { entryStore.delete(entry) }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will permanently delete this entry. This cannot be undone.")
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
            let nsStr       = editedBody as NSString
            if insertIndex <= nsStr.length {
                editedBody = nsStr.replacingCharacters(
                    in: NSRange(location: insertIndex, length: 0), with: tag)
                DispatchQueue.main.async {
                    textView.setSelectedRange(
                        NSRange(location: insertIndex + (tag as NSString).length, length: 0))
                }
                return
            }
        }
        editedBody += tag
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
        guard let entry else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories    = false
        panel.allowedContentTypes     = [.image]
        panel.begin { response in
            guard response == .OK else { return }
            DispatchQueue.main.async {
                let result = entryStore.addPhotos(to: entry, from: panel.urls)
                editedPhotos.append(contentsOf: result.photos)
                if !result.tag.isEmpty { insertTag(result.tag) }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider], entry: Entry) {
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
            let result = entryStore.addPhotos(to: entry, from: urls)
            editedPhotos.append(contentsOf: result.photos)
            if !result.tag.isEmpty { insertTag(result.tag) }
        }
    }

    private func updatePhoto(_ id: UUID, alignment: PhotoAlignment? = nil,
                              size: PhotoSize? = nil, caption: String? = nil) {
        guard let idx = editedPhotos.firstIndex(where: { $0.id == id }) else { return }
        if let alignment { editedPhotos[idx].alignment = alignment }
        if let size      { editedPhotos[idx].size      = size      }
        if let caption   { editedPhotos[idx].caption   = caption   }
    }

    private func removePhoto(_ photo: EntryPhoto, from entry: Entry) {
        editedBody = editedBody
            .replacingOccurrences(of: "\n![photo:\(photo.filename)]\n", with: "\n")
            .replacingOccurrences(of: "![photo:\(photo.filename)]\n", with: "")
            .replacingOccurrences(of: "![photo:\(photo.filename)]",  with: "")

        if let tagRange = editedBody.range(of: #"\!\[gallery:[^\]]*\]"#, options: .regularExpression) {
            let tag       = String(editedBody[tagRange])
            let filenames = tag
                .replacingOccurrences(of: "![gallery:", with: "")
                .replacingOccurrences(of: "]", with: "")
                .components(separatedBy: "|")
                .filter { $0 != photo.filename }
            if filenames.isEmpty {
                editedBody = editedBody.replacingOccurrences(of: tag, with: "")
            } else if filenames.count == 1 {
                editedBody = editedBody.replacingOccurrences(
                    of: tag, with: "![photo:\(filenames[0])]")
            } else {
                editedBody = editedBody.replacingOccurrences(
                    of: tag, with: "![gallery:\(filenames.joined(separator: "|"))]")
            }
        }
        entryStore.deletePhoto(photo, from: entry)
        editedPhotos.removeAll { $0.id == photo.id }
    }

    private func attemptDiscardEdit() {
        if hasUnsavedChanges {
            showDiscardAlert = true
        } else {
            isEditing    = false
            editedBody   = ""
            editedPhotos = []
            onEditingChanged?(false)
        }
    }

    private func saveEdit(body: String, photos: [EntryPhoto]) {
        guard let entry else { return }
        let updated = Entry(
            id:          entry.id,
            date:        entry.date,
            city:        entry.city,
            region:      entry.region,
            country:     entry.country,
            continent:   entry.continent,
            sublocation: entry.sublocation,
            latitude:    entry.latitude,
            longitude:   entry.longitude,
            body:        body,
            createdAt:   entry.createdAt,
            photos:      photos
        )
        entryStore.save(updated)
    }

    /// Rebuilds every ![gallery:...] tag in editedBody so its filename
    /// sequence matches the current order of editedPhotos. Called whenever
    /// editedPhotos changes so a drag-to-reorder in the thumbnail strip is
    /// immediately reflected in the underlying Markdown text.
    private func syncGalleryTagOrder() {
        guard editedBody.contains("![gallery:") else { return }

        // Current filename order from the thumbnail strip
        let currentOrder = editedPhotos.map { $0.filename }

        // Regex finds every ![gallery:f1|f2|...] tag
        guard let regex = try? NSRegularExpression(
            pattern: #"\!\[gallery:[^\]]+\]"#
        ) else { return }

        let nsBody  = editedBody as NSString
        let matches = regex.matches(
            in: editedBody,
            range: NSRange(location: 0, length: nsBody.length)
        )

        // Work in reverse so earlier match ranges stay valid as we replace
        var result = editedBody
        for match in matches.reversed() {
            let tag       = nsBody.substring(with: match.range)
            let filenames = tag
                .replacingOccurrences(of: "![gallery:", with: "")
                .replacingOccurrences(of: "]", with: "")
                .components(separatedBy: "|")

            // Keep only the filenames that belong to this gallery, but in
            // the order they now appear in the thumbnail strip
            let reordered = currentOrder.filter { filenames.contains($0) }
            guard !reordered.isEmpty else { continue }

            let newTag = "![gallery:\(reordered.joined(separator: "|"))]"
            result = (result as NSString)
                .replacingCharacters(in: match.range, with: newTag)
        }

        if result != editedBody { editedBody = result }
    }
}

// MARK: - Save button style

/// A button style whose appearance does not change when the window loses
/// focus. SwiftUI's .borderedProminent defers to the system accent color,
/// which macOS intentionally dims on inactive windows — making the Save
/// button nearly invisible against a light toolbar background.
///
/// This style uses explicit NSColor values so it is unaffected by window
/// key state, matching the appearance in both active and inactive windows.
struct SteadySaveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlAccentColor))
                    // Slight dim on press for tactile feedback,
                    // but never dims due to window focus state.
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
    }
}

// MARK: - Photo reorder drop delegate

struct PhotoDropDelegate: DropDelegate {
    let targetPhoto: EntryPhoto
    @Binding var photos: [EntryPhoto]
    @Binding var draggingID: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard
            let draggingID,
            draggingID != targetPhoto.id,
            let fromIdx = photos.firstIndex(where: { $0.id == draggingID }),
            let toIdx   = photos.firstIndex(where: { $0.id == targetPhoto.id })
        else { return }

        withAnimation {
            photos.move(fromOffsets: IndexSet(integer: fromIdx),
                        toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Inline body renderer (read mode)

struct InlineEntryBody: View {
    let entry: Entry
    let entryStore: EntryStore
    let themeManager: ThemeManager

    var body: some View {
        // For very large entries, Textual's markdown renderer becomes too slow
        // to lay out in real time. Above 100KB we fall back to plain text
        // rendering which is instant regardless of content size.
        let bodySize = entry.body.utf8.count
        let isLarge  = bodySize >= 100_000

        return VStack(alignment: .leading, spacing: 12) {
            if isLarge {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(themeManager.current.secondaryText)
                    Text("This entry is large — showing plain text for performance.")
                        .font(.caption)
                        .foregroundColor(themeManager.current.secondaryText)
                }
                .padding(.bottom, 4)

                // Split into paragraphs so SwiftUI lays out smaller chunks
                // rather than measuring one enormous text block at once.
                ForEach(entry.body.components(separatedBy: "\n\n").indices, id: \.self) { i in
                    let paragraph = entry.body.components(separatedBy: "\n\n")[i]
                    if !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(paragraph)
                            .font(themeManager.current.bodyFont)
                            .foregroundColor(themeManager.current.primaryText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                let segments = parseSegments(body: entry.body, photos: entry.photos)
                ForEach(segments) { segment in
                    switch segment.kind {
                    case .text(let md):
                        if !md.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            StructuredText(markdown: hardBreaked(stripUnsupported(md)))
                                .textual.structuredTextStyle(.default)
                                .textual.textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    case .photo(let photo):
                        InlinePhotoView(
                            photo: photo, entry: entry,
                            entryStore: entryStore, themeManager: themeManager)
                    case .gallery(let photos):
                        GalleryView(
                            photos: photos, entry: entry,
                            entryStore: entryStore, themeManager: themeManager)
                    }
                }
            }
        }
    }

    private func stripUnsupported(_ text: String) -> String {
        var result = text
        while let open  = result.range(of: "~~"),
              let close = result.range(of: "~~", range: open.upperBound..<result.endIndex) {
            let content = String(result[open.upperBound..<close.lowerBound])
            result.replaceSubrange(open.lowerBound...close.upperBound, with: content)
        }
        return result
    }

    private func hardBreaked(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        for (i, line) in lines.enumerated() {
            let isLast      = i == lines.count - 1
            let nextIsBlank = !isLast && lines[i + 1].trimmingCharacters(in: .whitespaces).isEmpty
            let trimmed     = line.trimmingCharacters(in: .whitespaces)
            let isMarkdown  = trimmed.isEmpty
                || trimmed.hasPrefix("#")   || trimmed.hasPrefix("-")
                || trimmed.hasPrefix("*")   || trimmed.hasPrefix(">")
                || trimmed.hasPrefix("`")   || trimmed.hasPrefix("|")
                || trimmed.hasPrefix("---") || trimmed.hasPrefix("***")
                || trimmed.hasPrefix("___")
                || trimmed.range(of: #"^\d+\."#, options: .regularExpression) != nil
            result.append(!isMarkdown && !isLast && !nextIsBlank ? line + "  " : line)
        }
        return result.joined(separator: "\n")
    }

    private func parseSegments(body: String, photos: [EntryPhoto]) -> [BodySegment] {
        var segments: [BodySegment] = []
        var remaining = body
        let byFilename = Dictionary(uniqueKeysWithValues: photos.map { ($0.filename, $0) })

        while !remaining.isEmpty {
            let photoRange   = remaining.range(of: #"\!\[photo:[^\]]+\]"#,   options: .regularExpression)
            let galleryRange = remaining.range(of: #"\!\[gallery:[^\]]+\]"#, options: .regularExpression)

            let nextRange: Range<String.Index>?
            let isGallery: Bool
            switch (photoRange, galleryRange) {
            case (nil, nil):     nextRange = nil; isGallery = false
            case (let p?, nil):  nextRange = p;   isGallery = false
            case (nil, let g?):  nextRange = g;   isGallery = true
            case (let p?, let g?):
                if p.lowerBound <= g.lowerBound { nextRange = p; isGallery = false }
                else                            { nextRange = g; isGallery = true  }
            }

            guard let tagRange = nextRange else {
                segments.append(BodySegment(kind: .text(remaining)))
                break
            }

            let before = String(remaining[remaining.startIndex..<tagRange.lowerBound])
            if !before.isEmpty { segments.append(BodySegment(kind: .text(before))) }

            let tag = String(remaining[tagRange])
            if isGallery {
                let filenames     = tag
                    .replacingOccurrences(of: "![gallery:", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    .components(separatedBy: "|")
                let galleryPhotos = filenames.compactMap { byFilename[$0] }
                if !galleryPhotos.isEmpty {
                    segments.append(BodySegment(kind: .gallery(galleryPhotos)))
                }
            } else {
                let filename = tag
                    .replacingOccurrences(of: "![photo:", with: "")
                    .replacingOccurrences(of: "]", with: "")
                if let photo = byFilename[filename] {
                    segments.append(BodySegment(kind: .photo(photo)))
                }
            }
            remaining = String(remaining[tagRange.upperBound...])
        }
        return segments
    }
}

// MARK: - Body segment

struct BodySegment: Identifiable {
    let id = UUID()
    enum Kind {
        case text(String)
        case photo(EntryPhoto)
        case gallery([EntryPhoto])
    }
    let kind: Kind
}

// MARK: - Inline photo view (read mode)

struct InlinePhotoView: View {
    let photo: EntryPhoto
    let entry: Entry
    let entryStore: EntryStore
    let themeManager: ThemeManager
    @State private var image: NSImage? = nil

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let img = image {
                    let aspect         = img.size.width / img.size.height
                    let frameAlignment = alignment(for: photo.alignment)
                    let hAlign         = hAlignment(for: photo.alignment)

                    VStack(alignment: hAlign, spacing: 4) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .aspectRatio(aspect, contentMode: .fit)
                            .frame(maxWidth: photoMaxWidth())
                            .cornerRadius(4)

                        if let caption = photo.caption, !caption.isEmpty {
                            Text(caption)
                                .font(themeManager.current.bodyFont)
                                .foregroundColor(themeManager.current.primaryText.opacity(0.6))
                                .frame(maxWidth: photoMaxWidth())
                                .multilineTextAlignment(photo.alignment == .center ? .center : .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 160)
                        .overlay(ProgressView())
                }
            }
        }
        .onAppear { loadImage() }
    }

    private func alignment(for a: PhotoAlignment) -> Alignment {
        switch a { case .left: return .leading; case .center: return .center; case .right: return .trailing }
    }

    private func hAlignment(for a: PhotoAlignment) -> HorizontalAlignment {
        switch a { case .left: return .leading; case .center: return .center; case .right: return .trailing }
    }

    private func photoMaxWidth() -> CGFloat {
        switch photo.size {
        case .small:  return 200
        case .medium: return 380
        case .large:  return 560
        case .full:   return .infinity
        }
    }

    private func loadImage() {
        let url = entryStore.photoURL(for: entry, filename: photo.filename)
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSImage(contentsOf: url)
            DispatchQueue.main.async { image = img }
        }
    }
}

// MARK: - Gallery view (read mode)

/// Renders photos in rows of up to 3, wrapping automatically.
struct GalleryView: View {
    let photos: [EntryPhoto]
    let entry: Entry
    let entryStore: EntryStore
    let themeManager: ThemeManager

    private var rows: [[EntryPhoto]] {
        stride(from: 0, to: photos.count, by: 3).map {
            Array(photos[$0..<min($0 + 3, photos.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(rows[rowIndex]) { photo in
                        GalleryPhotoCell(
                            photo: photo, entry: entry,
                            entryStore: entryStore, themeManager: themeManager)
                    }
                }
            }
        }
    }
}

// MARK: - Gallery photo cell (read mode)

struct GalleryPhotoCell: View {
    let photo: EntryPhoto
    let entry: Entry
    let entryStore: EntryStore
    let themeManager: ThemeManager
    @State private var image: NSImage? = nil

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let img = image {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: cellMaxWidth())
                        .cornerRadius(4)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 120)
                        .overlay(ProgressView())
                }
            }

            if let caption = photo.caption, !caption.isEmpty {
                Text(caption)
                    .font(themeManager.current.bodyFont)
                    .foregroundColor(themeManager.current.primaryText.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: cellMaxWidth())
            }
        }
        .frame(maxWidth: cellMaxWidth())
        .onAppear { loadImage() }
    }

    private func cellMaxWidth() -> CGFloat {
        switch photo.size {
        case .small:  return 120
        case .medium: return 200
        case .large:  return 300
        case .full:   return .infinity
        }
    }

    private func loadImage() {
        let url = entryStore.photoURL(for: entry, filename: photo.filename)
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSImage(contentsOf: url)
            DispatchQueue.main.async { image = img }
        }
    }
}

// MARK: - Edit mode photo thumbnail

struct EditPhotoThumb: View {
    let photo: EntryPhoto
    let entry: Entry
    let entryStore: EntryStore
    let isSelected: Bool
    var isDragging: Bool = false
    var onSelect: () -> Void
    var onUpdateAlignment: (PhotoAlignment) -> Void
    var onUpdateSize: (PhotoSize) -> Void
    var onUpdateCaption: (String) -> Void
    var onDelete: () -> Void
    @State private var image: NSImage? = nil
    @State private var captionText     = ""

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = image {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(6)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 80, height: 80)
                    }
                }
                .opacity(isDragging ? 0.4 : 1.0)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .onTapGesture { onSelect() }

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white, .black)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }

            if isSelected {
                VStack(spacing: 4) {
                    Picker("", selection: Binding(
                        get: { photo.alignment },
                        set: { onUpdateAlignment($0) }
                    )) {
                        Image(systemName: "text.alignleft")  .tag(PhotoAlignment.left)
                        Image(systemName: "text.aligncenter").tag(PhotoAlignment.center)
                        Image(systemName: "text.alignright") .tag(PhotoAlignment.right)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)

                    Picker("", selection: Binding(
                        get: { photo.size },
                        set: { onUpdateSize($0) }
                    )) {
                        ForEach(PhotoSize.allCases, id: \.self) { size in
                            Text(size.label).tag(size)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)

                    TextField("Caption…", text: $captionText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .frame(width: 120)
                        .onChange(of: captionText) { onUpdateCaption(captionText) }
                }
            }
        }
        .onAppear {
            loadImage()
            captionText = photo.caption ?? ""
        }
    }

    private func loadImage() {
        let url = entryStore.photoURL(for: entry, filename: photo.filename)
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSImage(contentsOf: url)
            DispatchQueue.main.async { image = img }
        }
    }
}
