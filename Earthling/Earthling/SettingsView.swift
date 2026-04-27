//
//  SettingsView.swift
//  Earthling
//
//  Created on 3/14/26.
//
//  The Settings window, opened via Cmd+, or the app menu.
//  Contains a visual theme picker grid split into light and dark sections.
//  Each theme is shown as a miniature app preview so the user can see
//  colours and typography before selecting.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    let columns = [GridItem(.adaptive(minimum: 140, maximum: 160))]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Light themes
                VStack(alignment: .leading, spacing: 10) {
                    Text("LIGHT THEMES")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppTheme.lightThemes) { theme in
                            ThemeCard(theme: theme)
                                .environmentObject(themeManager)
                        }
                    }
                }

                // Dark themes
                VStack(alignment: .leading, spacing: 10) {
                    Text("DARK THEMES")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppTheme.darkThemes) { theme in
                            ThemeCard(theme: theme)
                                .environmentObject(themeManager)
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 480, minHeight: 400)
    }
}

// MARK: - Theme card

struct ThemeCard: View {
    let theme: AppTheme
    @EnvironmentObject var themeManager: ThemeManager

    var isSelected: Bool { themeManager.current.id == theme.id }

    var body: some View {
        Button(action: { themeManager.select(theme) }) {
            VStack(spacing: 6) {
                // Miniature app preview
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.mainBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isSelected ? Color.accentColor : Color.gray.opacity(0.25),
                                    lineWidth: isSelected ? 2 : 0.5
                                )
                        )

                    HStack(spacing: 0) {
                        // Sidebar strip
                        RoundedRectangle(cornerRadius: 0)
                            .fill(theme.sidebarBackground)
                            .frame(width: 44)
                            .overlay(
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(["Kyoto", "Lisbon", "Oaxaca"], id: \.self) { place in
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Mar 10")
                                                .font(.system(size: 6))
                                                .foregroundColor(theme.secondaryText)
                                            Text(place)
                                                .font(.system(
                                                    size: 8,
                                                    design: theme.usesMono ? .monospaced :
                                                            theme.usesSerif ? .serif : .default
                                                ))
                                                .foregroundColor(theme.primaryText)
                                        }
                                        .padding(.bottom, 3)
                                        Divider()
                                            .background(theme.sidebarEntryBorder)
                                    }
                                    Spacer()
                                }
                                .padding(6)
                            )

                        Rectangle()
                            .fill(theme.sidebarBorder)
                            .frame(width: 0.5)

                        // Detail preview — uses primaryText to match actual rendering
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Kyoto")
                                .font(.system(
                                    size: 10, weight: .semibold,
                                    design: theme.usesMono ? .monospaced :
                                            theme.usesSerif ? .serif : .default
                                ))
                                .foregroundColor(theme.primaryText)
                            Text("Kansai · Japan")
                                .font(.system(size: 7))
                                .foregroundColor(theme.secondaryText)
                            Text("Arrived just before the rains. The streets near Gion were quieter than expected.")
                                .font(.system(
                                    size: 7,
                                    design: theme.usesMono ? .monospaced :
                                            theme.usesSerif ? .serif : .default
                                ))
                                .foregroundColor(theme.isDark ? Color.white.opacity(0.85) : Color.black.opacity(0.85))
                                .lineLimit(3)
                                .padding(.top, 2)
                        }
                        .padding(8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 80)

                // Theme name + selection indicator
                HStack {
                    Text(theme.name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(.primary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .buttonStyle(.plain)
    }
}
