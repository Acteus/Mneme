//
//  VaultViewModel.swift
//  Mneme
//
//  View model for the Knowledge Vault
//

import Foundation
import Combine

@MainActor
class VaultViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var searchResults: [Note] = []
    @Published var selectedNote: Note?
    @Published var searchQuery = "" {
        didSet {
            handleSearchQueryChange()
        }
    }
    @Published var isSearching = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var allTags: [(String, Int)] = []
    @Published var selectedTag: String?
    
    private let bridge = PythonBridge.shared
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Note Operations
    
    func loadNotes() async {
        isLoading = true
        error = nil
        
        do {
            let response = try await bridge.request("vault.get_all_notes", params: ["limit": 100])
            if let notesArray = response["notes"] as? [[String: Any]] {
                notes = notesArray.compactMap { Note.from(dict: $0) }
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createNote(title: String?, content: String, tags: [String] = []) async -> Note? {
        do {
            var params: [String: Any] = ["content": content]
            if let title = title {
                params["title"] = title
            }
            if !tags.isEmpty {
                params["tags"] = tags
            }
            
            let response = try await bridge.request("vault.create_note", params: params)
            if let note = Note.from(dict: response) {
                notes.insert(note, at: 0)
                await loadTags()
                return note
            }
        } catch {
            self.error = error.localizedDescription
        }
        return nil
    }
    
    func updateNote(_ note: Note, title: String?, content: String, tags: [String]) async -> Note? {
        do {
            var params: [String: Any] = ["note_id": note.id, "content": content]
            if let title = title {
                params["title"] = title
            }
            params["tags"] = tags
            
            let response = try await bridge.request("vault.update_note", params: params)
            if let updatedNote = Note.from(dict: response) {
                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                    notes[index] = updatedNote
                }
                await loadTags()
                return updatedNote
            }
        } catch {
            self.error = error.localizedDescription
        }
        return nil
    }
    
    func deleteNote(_ note: Note) async {
        do {
            _ = try await bridge.request("vault.delete_note", params: ["note_id": note.id])
            notes.removeAll { $0.id == note.id }
            if selectedNote?.id == note.id {
                selectedNote = nil
            }
            await loadTags()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Search
    
    private func handleSearchQueryChange() {
        // Cancel any previous search task
        searchTask?.cancel()
        
        let query = searchQuery
        
        if query.isEmpty {
            searchResults = []
            isSearching = false
            return
        }
        
        // Debounce by creating a new task with a delay
        searchTask = Task {
            // Wait 300ms before searching
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            await search(query: query)
        }
    }
    
    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        do {
            let response = try await bridge.request("vault.search", params: [
                "query": query,
                "limit": 20
            ])
            
            if let resultsArray = response["results"] as? [[String: Any]] {
                searchResults = resultsArray.compactMap { Note.from(dict: $0) }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func findRelated(to note: Note) async -> [Note] {
        do {
            let response = try await bridge.request("vault.find_related", params: [
                "note_id": note.id,
                "limit": 5
            ])
            
            if let relatedArray = response["related"] as? [[String: Any]] {
                return relatedArray.compactMap { Note.from(dict: $0) }
            }
        } catch {
            self.error = error.localizedDescription
        }
        return []
    }
    
    // MARK: - Tags
    
    func loadTags() async {
        do {
            let response = try await bridge.request("vault.get_all_tags")
            if let tagsArray = response["tags"] as? [[String: Any]] {
                allTags = tagsArray.compactMap { dict -> (String, Int)? in
                    guard let name = dict["name"] as? String,
                          let count = dict["count"] as? Int else {
                        return nil
                    }
                    return (name, count)
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func loadNotesByTag(_ tag: String) async {
        selectedTag = tag
        
        do {
            let response = try await bridge.request("vault.get_notes_by_tag", params: ["tag": tag])
            if let notesArray = response["notes"] as? [[String: Any]] {
                notes = notesArray.compactMap { Note.from(dict: $0) }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func clearTagFilter() async {
        selectedTag = nil
        await loadNotes()
    }
}
