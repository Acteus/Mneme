//
//  MnemeApp.swift
//  Mneme
//
//  A local-first macOS app for thinking, remembering, and deciding.
//

import SwiftUI

@main
struct MnemeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1100, height: 700)
        .commands {
            // Custom menu commands
            CommandGroup(after: .newItem) {
                Button("New Note") {
                    NotificationCenter.default.post(name: .newNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
                
                Button("New Decision") {
                    NotificationCenter.default.post(name: .newDecision, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .textEditing) {
                Button("Search Vault") {
                    NotificationCenter.default.post(name: .searchVault, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newNote = Notification.Name("newNote")
    static let newDecision = Notification.Name("newDecision")
    static let searchVault = Notification.Name("searchVault")
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 250)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("simulationRuns") private var simulationRuns = 1000
    @AppStorage("autoTagNotes") private var autoTagNotes = true
    
    var body: some View {
        Form {
            Section("Knowledge Vault") {
                Toggle("Auto-generate tags for notes", isOn: $autoTagNotes)
            }
            
            Section("Decision Simulator") {
                Stepper("Default simulation runs: \(simulationRuns)", value: $simulationRuns, in: 100...10000, step: 100)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("Mneme")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("A private thinking tool")
                .foregroundColor(.secondary)
            
            Divider()
                .frame(maxWidth: 200)
            
            VStack(spacing: 4) {
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Local-first. No cloud. No accounts.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }
}
