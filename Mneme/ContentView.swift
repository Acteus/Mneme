//
//  ContentView.swift
//  Mneme
//
//  A local-first macOS app for thinking, remembering, and deciding.
//

import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case vault = "Vault"
    case decisions = "Decisions"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .vault: return "brain.head.profile"
        case .decisions: return "scale.3d"
        }
    }
}

struct ContentView: View {
    @State private var selectedSection: AppSection = .vault
    @ObservedObject private var bridge = PythonBridge.shared  // Changed from @StateObject - singleton should use @ObservedObject
    
    // #region agent log
    private func logBody() {
        let logPath = "/Users/gdullas/Desktop/Projects/Mneme/.cursor/debug.log"
        let logEntry = "{\"location\":\"ContentView.swift:28\",\"message\":\"ContentView body evaluated\",\"data\":{\"isRunning\":\(bridge.isRunning)},\"timestamp\":\(Date().timeIntervalSince1970 * 1000),\"sessionId\":\"debug-session\",\"hypothesisId\":\"G\",\"runId\":\"post-fix-v3\"}\n"
        if let data = logEntry.data(using: .utf8), let handle = FileHandle(forWritingAtPath: logPath) { handle.seekToEndOfFile(); handle.write(data); handle.closeFile() } else { FileManager.default.createFile(atPath: logPath, contents: logEntry.data(using: .utf8)) }
    }
    // #endregion
    
    var body: some View {
        let _ = logBody()
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section {
                    ForEach(AppSection.allCases) { section in
                        Label(section.rawValue, systemImage: section.icon)
                            .tag(section)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mneme")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(bridge.isRunning ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                            Text(bridge.isRunning ? "Ready" : "Starting...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 140, ideal: 160, max: 200)
        } detail: {
            switch selectedSection {
            case .vault:
                VaultView()
            case .decisions:
                DecisionSimulatorView()
            }
        }
        .task {
            // Use Task.detached to break out of SwiftUI's view update context
            await Task.detached { @MainActor [bridge] in
                do {
                    try await bridge.start()
                } catch {
                    print("Failed to start Python backend: \(error)")
                }
            }.value
        }
    }
}

#Preview {
    ContentView()
}
