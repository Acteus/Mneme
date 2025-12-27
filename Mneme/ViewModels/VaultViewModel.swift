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
    @Published var searchQuery = ""
    @Published var isSearching = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var showError = false
    @Published var allTags: [(String, Int)] = []
    @Published var selectedTag: String?
    
    private let bridge = PythonBridge.shared
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Note Operations
    
    func loadNotes() async {
        // #region agent log
        let logPath = "/Users/gdullas/Desktop/Projects/Mneme/.cursor/debug.log"
        let logEntry = "{\"location\":\"VaultViewModel.swift:32\",\"message\":\"loadNotes - using detached task\",\"data\":{},\"timestamp\":\(Date().timeIntervalSince1970 * 1000),\"sessionId\":\"debug-session\",\"hypothesisId\":\"K\",\"runId\":\"post-fix-v5\"}\n"
        if let data = logEntry.data(using: .utf8), let handle = FileHandle(forWritingAtPath: logPath) { handle.seekToEndOfFile(); handle.write(data); handle.closeFile() } else { FileManager.default.createFile(atPath: logPath, contents: logEntry.data(using: .utf8)) }
        // #endregion
        
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
    
    /// Called from the View's onChange modifier - safe pattern for SwiftUI
    func handleSearchQueryChange(oldValue: String, newValue: String) {
        // #region agent log
        let logPath = "/Users/gdullas/Desktop/Projects/Mneme/.cursor/debug.log"
        let logEntry1 = "{\"location\":\"VaultViewModel.swift:107\",\"message\":\"handleSearchQueryChange entry (onChange)\",\"data\":{\"oldValue\":\"\(oldValue)\",\"newValue\":\"\(newValue)\"},\"timestamp\":\(Date().timeIntervalSince1970 * 1000),\"sessionId\":\"debug-session\",\"hypothesisId\":\"A\",\"runId\":\"post-fix\"}\n"
        if let data = logEntry1.data(using: .utf8), let handle = FileHandle(forWritingAtPath: logPath) { handle.seekToEndOfFile(); handle.write(data); handle.closeFile() } else { FileManager.default.createFile(atPath: logPath, contents: logEntry1.data(using: .utf8)) }
        // #endregion
        
        // Skip if value hasn't actually changed
        guard oldValue != newValue else { return }
        
        // Cancel any previous search task
        searchTask?.cancel()
        
        let query = newValue
        
        // Use Task to properly defer state changes
        searchTask = Task { @MainActor in
            // Yield to allow SwiftUI to finish its update cycle
            await Task.yield()
            
            // #region agent log
            let logEntry2 = "{\"location\":\"VaultViewModel.swift:125\",\"message\":\"searchTask started (onChange)\",\"data\":{\"query\":\"\(query)\"},\"timestamp\":\(Date().timeIntervalSince1970 * 1000),\"sessionId\":\"debug-session\",\"hypothesisId\":\"A\",\"runId\":\"post-fix\"}\n"
            if let data = logEntry2.data(using: .utf8), let handle = FileHandle(forWritingAtPath: logPath) { handle.seekToEndOfFile(); handle.write(data); handle.closeFile() }
            // #endregion
            
            if query.isEmpty {
                searchResults = []
                isSearching = false
                return
            }
            
            // Wait 300ms before searching (debounce)
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
        // #region agent log
        let logPath = "/Users/gdullas/Desktop/Projects/Mneme/.cursor/debug.log"
        let logEntry = "{\"location\":\"VaultViewModel.swift:189\",\"message\":\"loadNotesByTag called\",\"data\":{\"tag\":\"\(tag)\"},\"timestamp\":\(Date().timeIntervalSince1970 * 1000),\"sessionId\":\"debug-session\",\"hypothesisId\":\"D\"}\n"
        if let data = logEntry.data(using: .utf8), let handle = FileHandle(forWritingAtPath: logPath) { handle.seekToEndOfFile(); handle.write(data); handle.closeFile() } else { FileManager.default.createFile(atPath: logPath, contents: logEntry.data(using: .utf8)) }
        // #endregion
        
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
