//
//  AppTheme.swift
//  Earthling
//
//  Created on 3/14/26.
//
//  Defines the visual theme system. AppTheme is a value type describing
//  a complete set of colours and typography for the app. ThemeManager is
//  the ObservableObject that holds the active theme and persists the
//  user's choice to UserDefaults.
//
//  To add a new theme: define a static instance in the AppTheme extension,
//  then add it to the `all` array. No other changes are needed.
//

import SwiftUI
import Combine

// MARK: - Theme definition

struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let isDark: Bool

    let sidebarBackground:  Color
    let sidebarBorder:      Color
    let sidebarEntryBorder: Color
    let mainBackground:     Color
    let toolbarBackground:  Color
    let toolbarBorder:      Color
    let primaryText:        Color
    let secondaryText:      Color
    let tertiaryText:       Color

    let usesSerif: Bool
    let usesMono:  Bool

    var bodyFont: Font {
        if usesMono  { return .system(.body, design: .monospaced) }
        if usesSerif { return .system(.body, design: .serif) }
        return .system(.body, design: .default)
    }

    var titleFont: Font {
        if usesMono  { return .system(.title2, design: .monospaced) }
        if usesSerif { return .system(.title2, design: .serif) }
        return .system(.title2, design: .default)
    }

    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Built-in themes

extension AppTheme {

    static let modern = AppTheme(
        id: "modern", name: "Modern", isDark: false,
        sidebarBackground: Color(hex: "#F8F8F8"),
        sidebarBorder: Color(hex: "#E8E8E8"),
        sidebarEntryBorder: Color(hex: "#EFEFEF"),
        mainBackground: Color(hex: "#FFFFFF"),
        toolbarBackground: Color(hex: "#F5F5F5"),
        toolbarBorder: Color(hex: "#DCDCDC"),
        primaryText: Color(hex: "#1A1A1A"),
        secondaryText: Color(hex: "#888888"),
        tertiaryText: Color(hex: "#999999"),
        usesSerif: false, usesMono: false
    )

    static let warm = AppTheme(
        id: "warm", name: "Warm", isDark: false,
        sidebarBackground: Color(hex: "#EDE8DF"),
        sidebarBorder: Color(hex: "#D6CFBF"),
        sidebarEntryBorder: Color(hex: "#D6CFBF"),
        mainBackground: Color(hex: "#F7F3EC"),
        toolbarBackground: Color(hex: "#EDE8DF"),
        toolbarBorder: Color(hex: "#D6CFBF"),
        primaryText: Color(hex: "#2A2018"),
        secondaryText: Color(hex: "#9A8E7E"),
        tertiaryText: Color(hex: "#9A8E7E"),
        usesSerif: true, usesMono: false
    )

    static let dark = AppTheme(
        id: "dark", name: "Dark", isDark: true,
        sidebarBackground: Color(hex: "#2A2A2A"),
        sidebarBorder: Color(hex: "#3A3A3A"),
        sidebarEntryBorder: Color(hex: "#3A3A3A"),
        mainBackground: Color(hex: "#1C1C1E"),
        toolbarBackground: Color(hex: "#2A2A2A"),
        toolbarBorder: Color(hex: "#3A3A3A"),
        primaryText: Color(hex: "#F0F0F0"),
        secondaryText: Color(hex: "#777777"),
        tertiaryText: Color(hex: "#AAAAAA"),
        usesSerif: false, usesMono: false
    )

    static let terminal = AppTheme(
        id: "terminal", name: "Terminal", isDark: true,
        sidebarBackground: Color(hex: "#0A0F0A"),
        sidebarBorder: Color(hex: "#1A2A1A"),
        sidebarEntryBorder: Color(hex: "#1A2A1A"),
        mainBackground: Color(hex: "#0D120D"),
        toolbarBackground: Color(hex: "#0A0F0A"),
        toolbarBorder: Color(hex: "#1A2A1A"),
        primaryText: Color(hex: "#00FF00"),
        secondaryText: Color(hex: "#4A884A"),
        tertiaryText: Color(hex: "#00AA00"),
        usesSerif: false, usesMono: true
    )

    static let slate = AppTheme(
        id: "slate", name: "Slate", isDark: true,
        sidebarBackground: Color(hex: "#252D3D"),
        sidebarBorder: Color(hex: "#2E3A50"),
        sidebarEntryBorder: Color(hex: "#2E3A50"),
        mainBackground: Color(hex: "#1E2430"),
        toolbarBackground: Color(hex: "#252D3D"),
        toolbarBorder: Color(hex: "#2E3A50"),
        primaryText: Color(hex: "#C5D3E3"),
        secondaryText: Color(hex: "#6A7A92"),
        tertiaryText: Color(hex: "#7A92AE"),
        usesSerif: false, usesMono: false
    )

    static let lavender = AppTheme(
        id: "lavender", name: "Lavender", isDark: false,
        sidebarBackground: Color(hex: "#EDE5FF"),
        sidebarBorder: Color(hex: "#D9CCFA"),
        sidebarEntryBorder: Color(hex: "#D9CCFA"),
        mainBackground: Color(hex: "#F5F0FF"),
        toolbarBackground: Color(hex: "#EDE5FF"),
        toolbarBorder: Color(hex: "#D9CCFA"),
        primaryText: Color(hex: "#3A2070"),
        secondaryText: Color(hex: "#B09CD8"),
        tertiaryText: Color(hex: "#5A3EA0"),
        usesSerif: false, usesMono: false
    )

    static let sage = AppTheme(
        id: "sage", name: "Sage", isDark: false,
        sidebarBackground: Color(hex: "#E3EDE3"),
        sidebarBorder: Color(hex: "#C8DCC8"),
        sidebarEntryBorder: Color(hex: "#C8DCC8"),
        mainBackground: Color(hex: "#F0F5F0"),
        toolbarBackground: Color(hex: "#E3EDE3"),
        toolbarBorder: Color(hex: "#C8DCC8"),
        primaryText: Color(hex: "#1A3A1A"),
        secondaryText: Color(hex: "#8AAA8A"),
        tertiaryText: Color(hex: "#3A5A3A"),
        usesSerif: false, usesMono: false
    )

    static let rose = AppTheme(
        id: "rose", name: "Rose", isDark: false,
        sidebarBackground: Color(hex: "#FFE3E8"),
        sidebarBorder: Color(hex: "#F5C8D0"),
        sidebarEntryBorder: Color(hex: "#F5C8D0"),
        mainBackground: Color(hex: "#FFF0F3"),
        toolbarBackground: Color(hex: "#FFE3E8"),
        toolbarBorder: Color(hex: "#F5C8D0"),
        primaryText: Color(hex: "#4A1020"),
        secondaryText: Color(hex: "#C8909A"),
        tertiaryText: Color(hex: "#7A3040"),
        usesSerif: false, usesMono: false
    )

    static let dusk = AppTheme(
        id: "dusk", name: "Dusk", isDark: true,
        sidebarBackground: Color(hex: "#221D30"),
        sidebarBorder: Color(hex: "#2E2840"),
        sidebarEntryBorder: Color(hex: "#2E2840"),
        mainBackground: Color(hex: "#1A1525"),
        toolbarBackground: Color(hex: "#221D30"),
        toolbarBorder: Color(hex: "#2E2840"),
        primaryText: Color(hex: "#DDD0FF"),
        secondaryText: Color(hex: "#7A7090"),
        tertiaryText: Color(hex: "#8878BB"),
        usesSerif: false, usesMono: false
    )

    static let arctic = AppTheme(
        id: "arctic", name: "Arctic", isDark: false,
        sidebarBackground: Color(hex: "#EAF4FC"),
        sidebarBorder: Color(hex: "#CCE8F8"),
        sidebarEntryBorder: Color(hex: "#CCE8F8"),
        mainBackground: Color(hex: "#F5FAFE"),
        toolbarBackground: Color(hex: "#EAF4FC"),
        toolbarBorder: Color(hex: "#CCE8F8"),
        primaryText: Color(hex: "#042030"),
        secondaryText: Color(hex: "#88BBDD"),
        tertiaryText: Color(hex: "#1A4A6A"),
        usesSerif: false, usesMono: false
    )

    /// All available themes in display order.
    static let all: [AppTheme] = [
        .modern, .warm, .dark, .terminal,
        .slate, .lavender, .sage, .rose, .dusk, .arctic
    ]

    static let lightThemes: [AppTheme] = all.filter { !$0.isDark }
    static let darkThemes:  [AppTheme] = all.filter {  $0.isDark }
}

// MARK: - Theme manager

class ThemeManager: ObservableObject {
    @Published var current: AppTheme

    private let themeKey = "earthling.selectedTheme"

    init() {
        let savedID = UserDefaults.standard.string(forKey: "earthling.selectedTheme") ?? "modern"
        self.current = AppTheme.all.first { $0.id == savedID } ?? .modern
    }

    func select(_ theme: AppTheme) {
        current = theme
        UserDefaults.standard.set(theme.id, forKey: themeKey)
    }
}

// MARK: - Hex colour initialiser

extension Color {
    /// Creates a Color from a CSS-style hex string (e.g. "#FF8800" or "FF8800").
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)         / 255
        self.init(red: r, green: g, blue: b)
    }
}
