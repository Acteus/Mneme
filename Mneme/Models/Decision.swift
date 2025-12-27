//
//  Decision.swift
//  Mneme
//
//  Decision Simulator models
//

import Foundation

struct Decision: Identifiable, Codable, Hashable {
    let id: Int
    var title: String
    var description: String?
    var status: DecisionStatus
    let createdAt: Date
    var updatedAt: Date
    var choices: [Choice]
    var factors: [Factor]
    var scores: [Score]
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case choices, factors, scores
    }
    
    init(id: Int, title: String, description: String? = nil, status: DecisionStatus = .active,
         createdAt: Date = Date(), updatedAt: Date = Date(),
         choices: [Choice] = [], factors: [Factor] = [], scores: [Score] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.choices = choices
        self.factors = factors
        self.scores = scores
    }
}

enum DecisionStatus: String, Codable, CaseIterable {
    case active
    case resolved
    case archived
    
    var displayName: String {
        rawValue.capitalized
    }
}

struct Choice: Identifiable, Codable, Hashable {
    let id: Int
    let decisionId: Int
    var name: String
    var description: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case decisionId = "decision_id"
        case name, description
    }
}

struct Factor: Identifiable, Codable, Hashable {
    let id: Int
    let decisionId: Int
    var name: String
    var weight: Double
    var description: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case decisionId = "decision_id"
        case name, weight, description
    }
}

struct Score: Identifiable, Codable, Hashable {
    let id: Int
    let choiceId: Int
    let factorId: Int
    var score: Double
    var uncertainty: Double
    var notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case choiceId = "choice_id"
        case factorId = "factor_id"
        case score, uncertainty, notes
    }
    
    var id_: String { "\(choiceId)-\(factorId)" }
}

// MARK: - Simulation Results

struct SimulationResults: Codable {
    let numSimulations: Int
    let choiceResults: [Int: ChoiceResult]
    let rankings: [ChoiceResult]
    let winRates: [String: Double]
    
    enum CodingKeys: String, CodingKey {
        case numSimulations = "num_simulations"
        case choiceResults = "choice_results"
        case rankings
        case winRates = "win_rates"
    }
}

struct ChoiceResult: Codable, Identifiable {
    let choiceId: Int
    let name: String
    let deterministicScore: Double
    let mean: Double
    let std: Double
    let min: Double
    let max: Double
    let percentile5: Double
    let percentile25: Double
    let percentile50: Double
    let percentile75: Double
    let percentile95: Double
    let winRate: Double
    
    var id: Int { choiceId }
    
    enum CodingKeys: String, CodingKey {
        case choiceId = "choice_id"
        case name
        case deterministicScore = "deterministic_score"
        case mean, std, min, max
        case percentile5 = "percentile_5"
        case percentile25 = "percentile_25"
        case percentile50 = "percentile_50"
        case percentile75 = "percentile_75"
        case percentile95 = "percentile_95"
        case winRate = "win_rate"
    }
}

extension Decision {
    static func from(dict: [String: Any]) -> Decision? {
        guard let id = dict["id"] as? Int,
              let title = dict["title"] as? String else {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let createdAt = (dict["created_at"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date()
        let updatedAt = (dict["updated_at"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date()
        
        let statusStr = dict["status"] as? String ?? "active"
        let status = DecisionStatus(rawValue: statusStr) ?? .active
        
        var choices: [Choice] = []
        if let choicesArray = dict["choices"] as? [[String: Any]] {
            choices = choicesArray.compactMap { Choice.from(dict: $0) }
        }
        
        var factors: [Factor] = []
        if let factorsArray = dict["factors"] as? [[String: Any]] {
            factors = factorsArray.compactMap { Factor.from(dict: $0) }
        }
        
        var scores: [Score] = []
        if let scoresArray = dict["scores"] as? [[String: Any]] {
            scores = scoresArray.compactMap { Score.from(dict: $0) }
        }
        
        return Decision(
            id: id,
            title: title,
            description: dict["description"] as? String,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            choices: choices,
            factors: factors,
            scores: scores
        )
    }
}

extension Choice {
    static func from(dict: [String: Any]) -> Choice? {
        guard let id = dict["id"] as? Int,
              let decisionId = dict["decision_id"] as? Int,
              let name = dict["name"] as? String else {
            return nil
        }
        
        return Choice(
            id: id,
            decisionId: decisionId,
            name: name,
            description: dict["description"] as? String
        )
    }
}

extension Factor {
    static func from(dict: [String: Any]) -> Factor? {
        guard let id = dict["id"] as? Int,
              let decisionId = dict["decision_id"] as? Int,
              let name = dict["name"] as? String else {
            return nil
        }
        
        return Factor(
            id: id,
            decisionId: decisionId,
            name: name,
            weight: dict["weight"] as? Double ?? 1.0,
            description: dict["description"] as? String
        )
    }
}

extension Score {
    static func from(dict: [String: Any]) -> Score? {
        guard let id = dict["id"] as? Int,
              let choiceId = dict["choice_id"] as? Int,
              let factorId = dict["factor_id"] as? Int,
              let score = dict["score"] as? Double else {
            return nil
        }
        
        return Score(
            id: id,
            choiceId: choiceId,
            factorId: factorId,
            score: score,
            uncertainty: dict["uncertainty"] as? Double ?? 0,
            notes: dict["notes"] as? String
        )
    }
}

