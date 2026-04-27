//
//  EntryRowView.swift
//  Earthling
//
//  Created on 3/2/26.
//
//  A single row in the entry list sidebar. Renders date, city, and a
//  one-line preview of the body text. Supports two modes:
//    - Normal: tapping selects the entry in the detail panel.
//    - Export: a checkbox appears for multi-select before exporting.
//

import SwiftUI

struct EntryRowView: View {
    let entry: Entry
    let isSelected: Bool
    var isExportMode: Bool = false
    var isChecked: Bool    = false
    var onToggle: (() -> Void)? = nil

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 8) {
            if isExportMode {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isChecked
                        ? Color.accentColor
                        : themeManager.current.secondaryText)
                    .onTapGesture { onToggle?() }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(themeManager.current.secondaryText)

                Text(entry.city)
                    .font(.system(
                        .body,
                        design: themeManager.current.usesSerif ? .serif :
                                themeManager.current.usesMono  ? .monospaced : .default
                    ))
                    .foregroundColor(themeManager.current.primaryText)

                // Body preview — strips Markdown syntax for a clean one-liner.
                // Currently shows raw text including any photo tags; a future
                // pass could strip ![photo:...] and ![gallery:...] tags here.
                if !entry.body.isEmpty {
                    Text(entry.body)
                        .font(.caption)
                        .foregroundColor(themeManager.current.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected && !isExportMode
                ? themeManager.current.sidebarBorder
                : Color.clear
        )
        .contentShape(Rectangle())
        .overlay(
            Rectangle()
                .fill(themeManager.current.sidebarEntryBorder)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}
