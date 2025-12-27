//
//  Note.swift
//  Mneme
//
//  Knowledge Vault note model
//

import Foundation

struct Note: Identifiable, Codable, Hashable {
    let id: Int
    var title: String?
    var content: String
    var tags: [String]
    let createdAt: Date
    var updatedAt: Date
    var hasEmbedding: Bool
    var similarity: Double?  // Only set for search results
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case hasEmbedding = "has_embedding"
        case similarity
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        hasEmbedding = try container.decodeIfPresent(Bool.self, forKey: .hasEmbedding) ?? false
        similarity = try container.decodeIfPresent(Double.self, forKey: .similarity)
        
        // Parse ISO dates
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let createdStr = try container.decode(String.self, forKey: .createdAt)
        let updatedStr = try container.decode(String.self, forKey: .updatedAt)
        
        createdAt = dateFormatter.date(from: createdStr) ?? Date()
        updatedAt = dateFormatter.date(from: updatedStr) ?? Date()
    }
    
    init(id: Int, title: String?, content: String, tags: [String], 
         createdAt: Date, updatedAt: Date, hasEmbedding: Bool = false, similarity: Double? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.hasEmbedding = hasEmbedding
        self.similarity = similarity
    }
    
    /// Display title: uses title if available, otherwise first line of content
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        let firstLine = content.components(separatedBy: .newlines).first ?? content
        return String(firstLine.prefix(50)) + (firstLine.count > 50 ? "..." : "")
    }
    
    /// Preview of content for list display
    var preview: String {
        let lines = content.components(separatedBy: .newlines)
        let preview = lines.prefix(3).joined(separator: " ")
        return String(preview.prefix(150)) + (preview.count > 150 ? "..." : "")
    }
}

extension Note {
    static func from(dict: [String: Any]) -> Note? {
        guard let id = dict["id"] as? Int,
              let content = dict["content"] as? String else {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let createdAt = (dict["created_at"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date()
        let updatedAt = (dict["updated_at"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date()
        
        return Note(
            id: id,
            title: dict["title"] as? String,
            content: content,
            tags: dict["tags"] as? [String] ?? [],
            createdAt: createdAt,
            updatedAt: updatedAt,
            hasEmbedding: dict["has_embedding"] as? Bool ?? false,
            similarity: dict["similarity"] as? Double
        )
    }
}

