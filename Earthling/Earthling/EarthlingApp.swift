//
//  EarthlingApp.swift
//  Earthling
//
//  Created on 3/2/26.
//
//  App entry point. Owns the two root ObservableObjects — EntryStore and
//  ThemeManager — and injects them into the environment so all views can
//  access them without explicit passing.
//
//  Menu bar commands (Export, Toggle Map) post notifications that ContentView
//  listens for, keeping menu actions decoupled from view state.
//

import SwiftUI

@main
struct EarthlingApp: App {
    @StateObject private var entryStore   = EntryStore()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(entryStore)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.current.isDark ? .dark : .light)
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Export…") {
                    NotificationCenter.default.post(
                        name: .init("earthling.triggerExport"), object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
            }
            CommandMenu("View") {
                Button("Toggle Map") {
                    NotificationCenter.default.post(
                        name: .init("earthling.triggerMap"), object: nil)
                }
                .keyboardShortcut("m", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(themeManager)
        }
    }
}
