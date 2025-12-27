//
//  DecisionViewModel.swift
//  Mneme
//
//  View model for the Decision Simulator
//

import Foundation
import Combine

@MainActor
class DecisionViewModel: ObservableObject {
    @Published var decisions: [Decision] = []
    @Published var selectedDecision: Decision?
    @Published var simulationResults: SimulationResults?
    @Published var isSimulating = false
    @Published var isLoading = false
    @Published var error: String?
    
    private let bridge = PythonBridge.shared
    
    // MARK: - Decision Operations
    
    func loadDecisions(status: DecisionStatus? = nil) async {
        isLoading = true
        error = nil
        
        do {
            var params: [String: Any] = [:]
            if let status = status {
                params["status"] = status.rawValue
            }
            
            let response = try await bridge.request("decision.get_all", params: params)
            if let decisionsArray = response["decisions"] as? [[String: Any]] {
                decisions = decisionsArray.compactMap { Decision.from(dict: $0) }
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadDecision(_ id: Int) async -> Decision? {
        do {
            let response = try await bridge.request("decision.get", params: ["decision_id": id])
            return Decision.from(dict: response)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
    
    func createDecision(title: String, description: String?) async -> Decision? {
        do {
            var params: [String: Any] = ["title": title]
            if let desc = description {
                params["description"] = desc
            }
            
            let response = try await bridge.request("decision.create", params: params)
            if let decision = Decision.from(dict: response) {
                decisions.insert(decision, at: 0)
                return decision
            }
        } catch {
            self.error = error.localizedDescription
        }
        return nil
    }
    
    func deleteDecision(_ decision: Decision) async {
        do {
            _ = try await bridge.request("decision.delete", params: ["decision_id": decision.id])
            decisions.removeAll { $0.id == decision.id }
            if selectedDecision?.id == decision.id {
                selectedDecision = nil
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Choices
    
    func addChoice(to decision: Decision, name: String, description: String?) async -> Int? {
        do {
            var params: [String: Any] = [
                "decision_id": decision.id,
                "name": name
            ]
            if let desc = description {
                params["description"] = desc
            }
            
            let response = try await bridge.request("decision.add_choice", params: params)
            return response["choice_id"] as? Int
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Factors
    
    func addFactor(to decision: Decision, name: String, weight: Double, description: String?) async -> Int? {
        do {
            var params: [String: Any] = [
                "decision_id": decision.id,
                "name": name,
                "weight": weight
            ]
            if let desc = description {
                params["description"] = desc
            }
            
            let response = try await bridge.request("decision.add_factor", params: params)
            return response["factor_id"] as? Int
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Scores
    
    func setScore(choiceId: Int, factorId: Int, score: Double, uncertainty: Double = 0, notes: String? = nil) async {
        do {
            var params: [String: Any] = [
                "choice_id": choiceId,
                "factor_id": factorId,
                "score": score,
                "uncertainty": uncertainty
            ]
            if let notes = notes {
                params["notes"] = notes
            }
            
            _ = try await bridge.request("decision.set_score", params: params)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Simulation
    
    func runSimulation(for decision: Decision, runs: Int = 1000) async {
        isSimulating = true
        simulationResults = nil
        
        do {
            let response = try await bridge.request("decision.simulate", params: [
                "decision_id": decision.id,
                "num_runs": runs,
                "save_results": true
            ])
            
            // Parse simulation results
            if let data = try? JSONSerialization.data(withJSONObject: response),
               let results = try? JSONDecoder().decode(SimulationResults.self, from: data) {
                simulationResults = results
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isSimulating = false
    }
    
    func refreshSelectedDecision() async {
        guard let decision = selectedDecision else { return }
        if let updated = await loadDecision(decision.id) {
            selectedDecision = updated
        }
    }
}

