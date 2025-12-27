//
//  ContentView.swift
//  Mneme
//
//  A local-first macOS app for thinking, remembering, and deciding.
//

import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case vault = "Knowledge Vault"
    case decisions = "Decision Simulator"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .vault: return "brain.head.profile"
        case .decisions: return "scale.3d"
        }
    }
    
    var description: String {
        switch self {
        case .vault: return "Store and search your thoughts"
        case .decisions: return "Model and simulate decisions"
        }
    }
}

struct ContentView: View {
    @State private var selectedSection: AppSection? = .vault
    @StateObject private var bridge = PythonBridge.shared
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // App header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mneme")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Think. Remember. Decide.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                Divider()
                
                // Navigation
                List(AppSection.allCases, selection: $selectedSection) { section in
                    NavigationLink(value: section) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.rawValue)
                                    .font(.headline)
                                
                                Text(section.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: section.icon)
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                // Status
                HStack {
                    Circle()
                        .fill(bridge.isRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(bridge.isRunning ? "Backend running" : "Backend stopped")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            switch selectedSection {
            case .vault:
                VaultView()
            case .decisions:
                DecisionSimulatorView()
            case .none:
                WelcomeView()
            }
        }
        .task {
            // Start the Python backend
            do {
                try await bridge.start()
            } catch {
                print("Failed to start Python backend: \(error)")
            }
        }
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain")
                .font(.system(size: 72))
                .foregroundColor(.accentColor)
            
            Text("Welcome to Mneme")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your private thinking tool")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Divider()
                .frame(maxWidth: 300)
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "brain.head.profile",
                    title: "Knowledge Vault",
                    description: "Store notes and search by meaning, not keywords"
                )
                
                FeatureRow(
                    icon: "scale.3d",
                    title: "Decision Simulator",
                    description: "Model decisions and explore what-if scenarios"
                )
                
                FeatureRow(
                    icon: "lock.shield",
                    title: "Local-First",
                    description: "Everything runs on your Mac. No cloud. No accounts."
                )
            }
            .frame(maxWidth: 400)
        }
        .padding(48)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
