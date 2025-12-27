//
//  DecisionSimulatorView.swift
//  Mneme
//
//  Main view for the Decision Simulator
//

import SwiftUI

struct DecisionSimulatorView: View {
    @StateObject private var viewModel = DecisionViewModel()
    @State private var showingNewDecision = false
    
    var body: some View {
        NavigationSplitView {
            DecisionListView(
                decisions: viewModel.decisions,
                selectedDecision: $viewModel.selectedDecision,
                onDelete: { decision in
                    Task { await viewModel.deleteDecision(decision) }
                }
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 280)
            .toolbar {
                ToolbarItem {
                    Button(action: { showingNewDecision = true }) {
                        Label("New Decision", systemImage: "plus.circle")
                    }
                }
            }
        } detail: {
            if let decision = viewModel.selectedDecision {
                DecisionDetailView(
                    decision: decision,
                    viewModel: viewModel
                )
            } else {
                EmptyStateView(
                    icon: "scale.3d",
                    title: "No Decision Selected",
                    message: "Select a decision from the sidebar or create a new one"
                )
            }
        }
        .sheet(isPresented: $showingNewDecision) {
            NewDecisionSheet { title, description in
                Task {
                    if let decision = await viewModel.createDecision(title: title, description: description) {
                        viewModel.selectedDecision = decision
                    }
                }
            }
        }
        .task {
            do {
                try await PythonBridge.shared.start()
                await viewModel.loadDecisions()
            } catch {
                viewModel.error = error.localizedDescription
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}

// MARK: - Decision List

struct DecisionListView: View {
    let decisions: [Decision]
    @Binding var selectedDecision: Decision?
    let onDelete: (Decision) -> Void
    
    var body: some View {
        List(decisions, selection: $selectedDecision) { decision in
            DecisionRowView(decision: decision)
                .tag(decision)
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        onDelete(decision)
                    }
                }
        }
        .listStyle(.sidebar)
    }
}

struct DecisionRowView: View {
    let decision: Decision
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(decision.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                StatusBadge(status: decision.status)
            }
            
            if let description = decision.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label("\(decision.choices.count)", systemImage: "arrow.triangle.branch")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Label("\(decision.factors.count)", systemImage: "slider.horizontal.3")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: DecisionStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .active: return .blue
        case .resolved: return .green
        case .archived: return .gray
        }
    }
}

// MARK: - Decision Detail

struct DecisionDetailView: View {
    let decision: Decision
    @ObservedObject var viewModel: DecisionViewModel
    
    @State private var showingAddChoice = false
    @State private var showingAddFactor = false
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(decision.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let description = decision.description {
                    Text(description)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Setup").tag(0)
                Text("Scores").tag(1)
                Text("Results").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            Divider()
                .padding(.top, 8)
            
            // Tab content
            TabView(selection: $selectedTab) {
                DecisionSetupView(
                    decision: decision,
                    viewModel: viewModel,
                    showingAddChoice: $showingAddChoice,
                    showingAddFactor: $showingAddFactor
                )
                .tag(0)
                
                ScoreMatrixView(
                    decision: decision,
                    viewModel: viewModel
                )
                .tag(1)
                
                SimulationResultsView(
                    decision: decision,
                    viewModel: viewModel
                )
                .tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .sheet(isPresented: $showingAddChoice) {
            AddItemSheet(
                title: "Add Choice",
                namePlaceholder: "Choice name",
                descriptionPlaceholder: "Description (optional)"
            ) { name, description in
                Task {
                    _ = await viewModel.addChoice(to: decision, name: name, description: description)
                    await viewModel.refreshSelectedDecision()
                }
            }
        }
        .sheet(isPresented: $showingAddFactor) {
            AddFactorSheet { name, weight, description in
                Task {
                    _ = await viewModel.addFactor(to: decision, name: name, weight: weight, description: description)
                    await viewModel.refreshSelectedDecision()
                }
            }
        }
    }
}

// MARK: - Decision Setup

struct DecisionSetupView: View {
    let decision: Decision
    @ObservedObject var viewModel: DecisionViewModel
    @Binding var showingAddChoice: Bool
    @Binding var showingAddFactor: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Choices
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Choices")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: { showingAddChoice = true }) {
                            Label("Add", systemImage: "plus")
                        }
                    }
                    
                    if decision.choices.isEmpty {
                        Text("No choices yet. Add the options you're considering.")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                    } else {
                        ForEach(decision.choices) { choice in
                            ChoiceCard(choice: choice)
                        }
                    }
                }
                
                Divider()
                
                // Factors
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Factors")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: { showingAddFactor = true }) {
                            Label("Add", systemImage: "plus")
                        }
                    }
                    
                    if decision.factors.isEmpty {
                        Text("No factors yet. Add the criteria that matter to you.")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                    } else {
                        ForEach(decision.factors) { factor in
                            FactorCard(factor: factor)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct ChoiceCard: View {
    let choice: Choice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(choice.name)
                .font(.headline)
            
            if let description = choice.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct FactorCard: View {
    let factor: Factor
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(factor.name)
                    .font(.headline)
                
                if let description = factor.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Weight indicator
            VStack(alignment: .trailing) {
                Text("Weight")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1f", factor.weight))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Score Matrix

struct ScoreMatrixView: View {
    let decision: Decision
    @ObservedObject var viewModel: DecisionViewModel
    @State private var editingScore: (Choice, Factor)? = nil
    @State private var scoreValue: Double = 5.0
    @State private var uncertaintyValue: Double = 0.0
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: 120)
                    
                    ForEach(decision.factors) { factor in
                        VStack {
                            Text(factor.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("(\(String(format: "%.1f", factor.weight)))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 100)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.controlBackgroundColor))
                
                Divider()
                
                // Choice rows
                ForEach(decision.choices) { choice in
                    HStack(spacing: 0) {
                        Text(choice.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(width: 120, alignment: .leading)
                            .padding(.leading, 8)
                        
                        ForEach(decision.factors) { factor in
                            ScoreCell(
                                score: getScore(choice: choice, factor: factor),
                                onTap: {
                                    let current = getScore(choice: choice, factor: factor)
                                    scoreValue = current?.score ?? 5.0
                                    uncertaintyValue = current?.uncertainty ?? 0.0
                                    editingScore = (choice, factor)
                                }
                            )
                            .frame(width: 100)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                }
            }
            .padding()
        }
        .sheet(item: Binding(
            get: { editingScore.map { ScoreEdit(choice: $0.0, factor: $0.1) } },
            set: { editingScore = $0.map { ($0.choice, $0.factor) } }
        )) { scoreEdit in
            ScoreEditSheet(
                choice: scoreEdit.choice,
                factor: scoreEdit.factor,
                initialScore: scoreValue,
                initialUncertainty: uncertaintyValue
            ) { score, uncertainty in
                Task {
                    await viewModel.setScore(
                        choiceId: scoreEdit.choice.id,
                        factorId: scoreEdit.factor.id,
                        score: score,
                        uncertainty: uncertainty
                    )
                    await viewModel.refreshSelectedDecision()
                }
            }
        }
    }
    
    private func getScore(choice: Choice, factor: Factor) -> Score? {
        decision.scores.first { $0.choiceId == choice.id && $0.factorId == factor.id }
    }
}

struct ScoreEdit: Identifiable {
    let choice: Choice
    let factor: Factor
    var id: String { "\(choice.id)-\(factor.id)" }
}

struct ScoreCell: View {
    let score: Score?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                if let score = score {
                    Text(String(format: "%.1f", score.score))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if score.uncertainty > 0 {
                        Text("±\(String(format: "%.1f", score.uncertainty))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .background(score != nil ? scoreColor(score!.score) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
    
    private func scoreColor(_ value: Double) -> Color {
        let normalized = value / 10.0
        return Color.accentColor.opacity(normalized * 0.3 + 0.1)
    }
}

// MARK: - Simulation Results

struct SimulationResultsView: View {
    let decision: Decision
    @ObservedObject var viewModel: DecisionViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Run simulation button
            HStack {
                Spacer()
                
                Button(action: {
                    Task { await viewModel.runSimulation(for: decision) }
                }) {
                    Label(
                        viewModel.isSimulating ? "Simulating..." : "Run Simulation",
                        systemImage: "play.circle"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSimulating || decision.choices.isEmpty || decision.factors.isEmpty)
            }
            .padding(.horizontal)
            
            if viewModel.isSimulating {
                ProgressView()
                    .padding()
            } else if let results = viewModel.simulationResults {
                SimulationResultsContent(results: results)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No simulation results yet")
                        .foregroundColor(.secondary)
                    
                    Text("Set up your choices, factors, and scores, then run a simulation.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}

struct SimulationResultsContent: View {
    let results: SimulationResults
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Summary
                Text("Simulation: \(results.numSimulations) runs")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Rankings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rankings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    ForEach(Array(results.rankings.enumerated()), id: \.element.id) { index, result in
                        RankingCard(rank: index + 1, result: result)
                    }
                }
                
                Divider()
                
                // Win rates chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Win Rates")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    ForEach(results.rankings) { result in
                        WinRateBar(name: result.name, winRate: result.winRate)
                    }
                }
            }
            .padding()
        }
    }
}

struct RankingCard: View {
    let rank: Int
    let result: ChoiceResult
    
    var body: some View {
        HStack {
            // Rank badge
            Text("#\(rank)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(rank == 1 ? .yellow : .secondary)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.headline)
                
                HStack {
                    Text("Score: \(String(format: "%.2f", result.mean))")
                        .font(.caption)
                    
                    Text("±\(String(format: "%.2f", result.std))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(Int(result.winRate * 100))%")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
                
                Text("win rate")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct WinRateBar: View {
    let name: String
    let winRate: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                
                Spacer()
                
                Text("\(Int(winRate * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.controlBackgroundColor))
                    
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * winRate)
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
        }
    }
}

// MARK: - Sheets

struct NewDecisionSheet: View {
    let onSave: (String, String?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("New Decision")
                    .font(.headline)
                Spacer()
                Button("Create") { save() }
                    .disabled(title.isEmpty)
            }
            .padding()
            
            Divider()
            
            Form {
                TextField("What are you deciding?", text: $title)
                TextField("Description (optional)", text: $description)
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(minWidth: 400, minHeight: 200)
    }
    
    private func save() {
        onSave(title, description.isEmpty ? nil : description)
        dismiss()
    }
}

struct AddItemSheet: View {
    let title: String
    let namePlaceholder: String
    let descriptionPlaceholder: String
    let onSave: (String, String?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Add") { save() }
                    .disabled(name.isEmpty)
            }
            .padding()
            
            Divider()
            
            Form {
                TextField(namePlaceholder, text: $name)
                TextField(descriptionPlaceholder, text: $description)
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(minWidth: 350, minHeight: 180)
    }
    
    private func save() {
        onSave(name, description.isEmpty ? nil : description)
        dismiss()
    }
}

struct AddFactorSheet: View {
    let onSave: (String, Double, String?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var weight: Double = 5.0
    @State private var description = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Add Factor")
                    .font(.headline)
                Spacer()
                Button("Add") { save() }
                    .disabled(name.isEmpty)
            }
            .padding()
            
            Divider()
            
            Form {
                TextField("Factor name", text: $name)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Weight: \(String(format: "%.1f", weight))")
                        Spacer()
                    }
                    Slider(value: $weight, in: 1...10, step: 0.5)
                }
                
                TextField("Description (optional)", text: $description)
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(minWidth: 400, minHeight: 250)
    }
    
    private func save() {
        onSave(name, weight, description.isEmpty ? nil : description)
        dismiss()
    }
}

struct ScoreEditSheet: View {
    let choice: Choice
    let factor: Factor
    let initialScore: Double
    let initialUncertainty: Double
    let onSave: (Double, Double) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var score: Double
    @State private var uncertainty: Double
    
    init(choice: Choice, factor: Factor, initialScore: Double, initialUncertainty: Double, onSave: @escaping (Double, Double) -> Void) {
        self.choice = choice
        self.factor = factor
        self.initialScore = initialScore
        self.initialUncertainty = initialUncertainty
        self.onSave = onSave
        _score = State(initialValue: initialScore)
        _uncertainty = State(initialValue: initialUncertainty)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Set Score")
                    .font(.headline)
                Spacer()
                Button("Save") { save() }
            }
            .padding()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("How does \"\(choice.name)\" rate on \"\(factor.name)\"?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Score: \(String(format: "%.1f", score))")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("0 = worst, 10 = best")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $score, in: 0...10, step: 0.5)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Uncertainty: ±\(String(format: "%.1f", uncertainty))")
                        Spacer()
                        Text("How sure are you?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $uncertainty, in: 0...3, step: 0.25)
                }
                
                Text("Tip: Higher uncertainty means this score could vary more in simulations.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            
            Spacer()
        }
        .frame(minWidth: 400, minHeight: 280)
    }
    
    private func save() {
        onSave(score, uncertainty)
        dismiss()
    }
}

#Preview {
    DecisionSimulatorView()
}

