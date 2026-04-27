//
//  ContentView.swift
//  Earthling
//
//  Created on 3/2/26.
//
//  The root view. Implements a two-panel layout: a fixed-width sidebar on
//  the left and a detail/map panel on the right.
//
//  The sidebar has two modes:
//    Normal   — entry list with sort, map, export, and new-entry buttons.
//    Export   — checkboxes appear on each row; a selection is built before
//               the export sheet is presented.
//
//  The detail panel shows one of four states:
//    Map view        — WorldMapView with a close button overlay.
//    Welcome screen  — shown when the entry list is empty.
//    Entry detail    — EntryDetailView for the selected entry.
//    Placeholder     — "Select an entry" when nothing is selected.
//
//  Sort preference and window size are persisted via @AppStorage and
//  macOS window restoration respectively.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Sort mode

enum SortMode: String, CaseIterable {
    case entryDateDesc = "Entry Date (Newest)"
    case entryDateAsc  = "Entry Date (Oldest)"
    case createdDesc   = "Date Added (Newest)"
    case createdAsc    = "Date Added (Oldest)"
}

// MARK: - Content view

struct ContentView: View {
    @EnvironmentObject var entryStore: EntryStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedEntryID: UUID? = nil
    @State private var showingNewEntry    = false
    @State private var showingMap         = false
    @State private var isExportMode       = false
    @State private var checkedIDs: Set<UUID> = []
    @State private var showingExportSheet = false
    @State private var isDetailEditing    = false
    @State private var showingEditWarning = false
    @State private var pendingAction: PendingAction? = nil
    @AppStorage("earthling.sortMode") private var sortModeRaw: String = SortMode.entryDateDesc.rawValue

    /// Actions that may be blocked when an entry is being edited.
    enum PendingAction { case newEntry, toggleMap }

    var sortMode: SortMode {
        SortMode(rawValue: sortModeRaw) ?? .entryDateDesc
    }

    var sortedEntries: [Entry] {
        switch sortMode {
        case .entryDateDesc: return entryStore.entries.sorted { $0.date      > $1.date      }
        case .entryDateAsc:  return entryStore.entries.sorted { $0.date      < $1.date      }
        case .createdDesc:   return entryStore.entries.sorted { $0.createdAt > $1.createdAt }
        case .createdAsc:    return entryStore.entries.sorted { $0.createdAt < $1.createdAt }
        }
    }

    var checkedEntries: [Entry] { sortedEntries.filter { checkedIDs.contains($0.id) } }
    var allChecked: Bool { !sortedEntries.isEmpty && checkedIDs.count == sortedEntries.count }

    var body: some View {
        HSplitView {
            // MARK: Sidebar
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    if isExportMode {
                        Button(action: toggleSelectAll) {
                            Image(systemName: allChecked ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundColor(allChecked ? .accentColor : themeManager.current.secondaryText)
                        }
                        .buttonStyle(.plain)

                        Text("Select all")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(themeManager.current.secondaryText)

                        Spacer()

                        Button("Cancel") {
                            isExportMode = false
                            checkedIDs   = []
                        }
                        .foregroundColor(themeManager.current.secondaryText)
                        .font(.system(size: 13))

                        if !checkedIDs.isEmpty {
                            Button("Export") { showingExportSheet = true }
                                .buttonStyle(.borderedProminent)
                                .font(.system(size: 13))
                        }
                    } else {
                        Text("Earthling")
                            .font(.system(size: 15, weight: .thin))
                            .foregroundColor(themeManager.current.tertiaryText)
                        Spacer()

                        // New entry button — guarded when editing
                        Button(action: { guardedAction(.newEntry) }) {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(themeManager.current.primaryText)
                        }
                        .buttonStyle(.plain)

                        // Sort menu
                        Menu {
                            ForEach(SortMode.allCases, id: \.self) { mode in
                                Button(action: { sortModeRaw = mode.rawValue }) {
                                    HStack {
                                        Text(mode.rawValue)
                                        if sortMode == mode { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(themeManager.current.primaryText)
                                .contentShape(Rectangle())
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .colorMultiply(themeManager.current.primaryText)

                        // Map button — guarded when editing
                        Button(action: { guardedAction(.toggleMap) }) {
                            Image(systemName: showingMap ? "map.fill" : "map")
                                .foregroundColor(themeManager.current.primaryText)
                        }
                        .buttonStyle(.plain)
                        .disabled(entryStore.entries.isEmpty)

                        // Export button
                        Button(action: { isExportMode = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(themeManager.current.primaryText)
                        }
                        .buttonStyle(.plain)
                        .disabled(entryStore.entries.isEmpty)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(themeManager.current.toolbarBackground)
                .overlay(
                    Rectangle()
                        .fill(themeManager.current.toolbarBorder)
                        .frame(height: 0.5),
                    alignment: .bottom
                )
                .animation(.easeInOut(duration: 0.15), value: isExportMode)

                // Entry list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedEntries) { entry in
                            EntryRowView(
                                entry: entry,
                                isSelected: selectedEntryID == entry.id,
                                isExportMode: isExportMode,
                                isChecked: checkedIDs.contains(entry.id),
                                onToggle: { toggleCheck(entry.id) }
                            )
                            .environmentObject(themeManager)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isExportMode {
                                    toggleCheck(entry.id)
                                } else {
                                    selectedEntryID = entry.id
                                    showingMap      = false
                                }
                            }
                        }
                    }
                }
            }
            .background(themeManager.current.sidebarBackground)
            .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)

            // MARK: Detail / Map panel
            if showingMap {
                VStack(spacing: 0) {
                    // Themed toolbar matching the rest of the app
                    HStack {
                        Spacer()
                        Button(action: { showingMap = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(themeManager.current.secondaryText)
                        }
                        .buttonStyle(.plain)
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

                    WorldMapView(entries: entryStore.entries) { entryID in
                        selectedEntryID = entryID
                        showingMap      = false
                    }
                }
            } else if entryStore.entries.isEmpty {
                WelcomeView()
                    .environmentObject(themeManager)
            } else if let selectedID = selectedEntryID {
                EntryDetailView(entryID: selectedID, onEditingChanged: { editing in
                    isDetailEditing = editing
                })
                .environmentObject(entryStore)
                .environmentObject(themeManager)
            } else {
                ZStack {
                    themeManager.current.mainBackground.ignoresSafeArea()
                    Text("Select an entry")
                        .foregroundColor(themeManager.current.secondaryText)
                }
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            NewEntryView(onSave: { savedID in selectedEntryID = savedID })
                .environmentObject(entryStore)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(entries: checkedEntries, entryStore: entryStore) {
                isExportMode       = false
                checkedIDs         = []
                showingExportSheet = false
            }
            .environmentObject(themeManager)
        }
        // Warning shown when a guarded action is attempted during editing.
        .confirmationDialog(
            "You have unsaved changes",
            isPresented: $showingEditWarning,
            titleVisibility: .visible
        ) {
            Button("Discard changes", role: .destructive) {
                isDetailEditing = false
                executePendingAction()
            }
            Button("Keep editing", role: .cancel) {
                pendingAction = nil
            }
        } message: {
            Text("Save or discard your changes before continuing.")
        }
        // Menu bar commands post notifications so they work regardless of focus.
        .onReceive(NotificationCenter.default.publisher(for: .init("earthling.triggerExport"))) { _ in
            if !entryStore.entries.isEmpty { isExportMode = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("earthling.triggerMap"))) { _ in
            if !entryStore.entries.isEmpty { guardedAction(.toggleMap) }
        }
    }

    // MARK: - Edit guard

    /// Checks whether an edit is in progress before executing an action.
    /// If editing, stores the action and shows a warning dialog instead.
    private func guardedAction(_ action: PendingAction) {
        if isDetailEditing {
            pendingAction = action
            showingEditWarning = true
        } else {
            pendingAction = action
            executePendingAction()
        }
    }

    private func executePendingAction() {
        switch pendingAction {
        case .newEntry:    showingNewEntry = true
        case .toggleMap:   showingMap.toggle()
        case .none:        break
        }
        pendingAction = nil
    }

    // MARK: - Helpers

    private func toggleCheck(_ id: UUID) {
        if checkedIDs.contains(id) { checkedIDs.remove(id) } else { checkedIDs.insert(id) }
    }

    private func toggleSelectAll() {
        checkedIDs = allChecked ? [] : Set(sortedEntries.map { $0.id })
    }
}

// MARK: - Export sheet

struct ExportSheet: View {
    let entries: [Entry]
    let entryStore: EntryStore
    let onDone: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var exportFile: ExportFile? = nil
    @State private var showingPageBreakChoice  = false

    var isSingleEntry: Bool { entries.count == 1 }

    var body: some View {
        VStack(spacing: 24) {
            Text("Export \(entries.count) \(isSingleEntry ? "entry" : "entries")")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(themeManager.current.primaryText)

            Divider().background(themeManager.current.sidebarBorder)

            VStack(spacing: 12) {
                ExportButton(title: "JSON", subtitle: "Full structured export",
                             icon: "doc.text", theme: themeManager.current) {
                    if let data = ExportManager.exportJSON(entries: entries, entryStore: entryStore) {
                        exportFile = ExportFile(data: data, name: "earthling-export.json", type: .json)
                    }
                }

                ExportButton(title: "CSV", subtitle: "Spreadsheet-friendly",
                             icon: "tablecells", theme: themeManager.current) {
                    if let data = ExportManager.exportCSV(entries: entries).data(using: .utf8) {
                        exportFile = ExportFile(data: data, name: "earthling-export.csv",
                                                type: .commaSeparatedText)
                    }
                }

                if isSingleEntry {
                    ExportButton(title: "PDF", subtitle: "Single entry document",
                                 icon: "doc.richtext", theme: themeManager.current) {
                        if let entry = entries.first {
                            let data = ExportManager.exportPDF(entry: entry, entryStore: entryStore)
                            exportFile = ExportFile(data: data,
                                                    name: ExportManager.pdfFilename(for: entry),
                                                    type: .pdf)
                        }
                    }
                } else {
                    ExportButton(title: "PDF — one per entry",
                                 subtitle: "\(entries.count) PDF files saved to a folder",
                                 icon: "doc.richtext", theme: themeManager.current) {
                        ExportManager.pickFolderAndExportPDFs(entries: entries,
                                                               entryStore: entryStore) { success in
                            if success { onDone() }
                        }
                    }

                    ExportButton(title: "PDF — combined",
                                 subtitle: "All entries in one document",
                                 icon: "doc.on.doc", theme: themeManager.current) {
                        showingPageBreakChoice = true
                    }
                }
            }

            Divider().background(themeManager.current.sidebarBorder)

            Button("Cancel") { onDone() }
                .foregroundColor(themeManager.current.secondaryText)
        }
        .padding(28)
        .frame(width: 360)
        .background(themeManager.current.mainBackground)
        .confirmationDialog(
            "How should entries be laid out?",
            isPresented: $showingPageBreakChoice,
            titleVisibility: .visible
        ) {
            Button("One entry per page") {
                let data = ExportManager.exportPDFCombined(entries: entries,
                                                            pageBreakPerEntry: true,
                                                            entryStore: entryStore)
                exportFile = ExportFile(data: data, name: "earthling-journal.pdf", type: .pdf)
            }
            Button("Continuous — no page breaks") {
                let data = ExportManager.exportPDFCombined(entries: entries,
                                                            pageBreakPerEntry: false,
                                                            entryStore: entryStore)
                exportFile = ExportFile(data: data, name: "earthling-journal.pdf", type: .pdf)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose how entries flow in the combined PDF")
        }
        .fileExporter(
            isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
            document: exportFile,
            contentType: exportFile?.type ?? .json,
            defaultFilename: exportFile?.name ?? "export"
        ) { _ in
            exportFile = nil
            onDone()
        }
    }
}

// MARK: - Export button

struct ExportButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(theme.primaryText)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(theme.primaryText)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.sidebarBackground)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Export file document

/// FileDocument wrapper used by SwiftUI's fileExporter modifier.
struct ExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .pdf] }
    var data: Data
    var name: String
    var type: UTType

    init(data: Data, name: String, type: UTType) {
        self.data = data
        self.name = name
        self.type = type
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        name = "export"
        type = .json
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Welcome view

/// Shown in the detail panel when no entries exist yet.
/// Cycles through "safe travels" phrases in various languages.
struct WelcomeView: View {
    @EnvironmentObject var themeManager: ThemeManager

    private let phrases: [(String, String)] = [
        ("Bon voyage",             "French"),
        ("Safe travels",           "English"),
        ("Gute Reise",             "German"),
        ("Buon viaggio",           "Italian"),
        ("Buen viaje",             "Spanish"),
        ("Boa viagem",             "Portuguese"),
        ("Goede reis",             "Dutch"),
        ("God resa",               "Swedish"),
        ("Счастливого пути",       "Russian"),
        ("İyi yolculuklar",        "Turkish"),
        ("良い旅を",                "Japanese"),
        ("一路平安",                "Chinese (Simplified)"),
        ("一路順風",                "Chinese (Traditional)"),
        ("좋은 여행 되세요",         "Korean"),
        ("رحلة سعيدة",             "Arabic"),
        ("शुभ यात्रा",              "Hindi"),
        ("Καλό ταξίδι",            "Greek"),
        ("Szczęśliwej podróży",    "Polish"),
        ("Šťastnou cestu",         "Czech"),
        ("Selamat jalan",          "Indonesian"),
        ("Maligayang paglalakbay", "Filipino"),
        ("Chúc thượng lộ bình an", "Vietnamese"),
        ("เดินทางปลอดภัย",         "Thai"),
        ("Felice viaggio",         "Italian"),
    ]

    @State private var currentIndex = 0
    @State private var opacity      = 1.0

    var body: some View {
        ZStack {
            themeManager.current.mainBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                VStack(spacing: 8) {
                    Text(phrases[currentIndex].0)
                        .font(.system(size: 36, weight: .thin))
                        .foregroundColor(themeManager.current.primaryText)
                        .opacity(opacity)
                        .animation(.easeInOut(duration: 0.6), value: opacity)

                    Text(phrases[currentIndex].1)
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(themeManager.current.secondaryText)
                        .opacity(opacity)
                        .animation(.easeInOut(duration: 0.6), value: opacity)
                }

                HStack(spacing: 6) {
                    Text("Click")
                    Image(systemName: "square.and.pencil")
                    Text("to write your first entry")
                }
                .font(.system(size: 13, weight: .light))
                .foregroundColor(themeManager.current.secondaryText)
            }
            .padding(40)
        }
        .onAppear { startCycling() }
    }

    private func startCycling() {
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            withAnimation { opacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                currentIndex = (currentIndex + 1) % phrases.count
                withAnimation { opacity = 1 }
            }
        }
    }
}
