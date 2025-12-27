//
//  VaultView.swift
//  Mneme
//
//  Main view for the Knowledge Vault
//

import SwiftUI

struct VaultView: View {
    @StateObject private var viewModel = VaultViewModel()
    @State private var showingNewNote = false
    @State private var editingNote: Note?
    @State private var relatedNotes: [Note] = []
    @State private var showingRelated = false
    
    // #region agent log
    private func logStartup() {
        let logPath = "/Users/gdullas/Desktop/Projects/Mneme/.cursor/debug.log"
        let logEntry = "{\"location\":\"VaultView.swift:17\",\"message\":\"VaultView body evaluated - NEW CODE RUNNING\",\"data\":{\"version\":\"post-fix-v2\"},\"timestamp\":\(Date().timeIntervalSince1970 * 1000),\"sessionId\":\"debug-session\",\"runId\":\"post-fix-v2\"}\n"
        if let data = logEntry.data(using: .utf8), let handle = FileHandle(forWritingAtPath: logPath) { handle.seekToEndOfFile(); handle.write(data); handle.closeFile() } else { FileManager.default.createFile(atPath: logPath, contents: logEntry.data(using: .utf8)) }
    }
    // #endregion
    
    var body: some View {
        let _ = logStartup()
        NavigationSplitView {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $viewModel.searchQuery, placeholder: "Search by meaning...")
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .onChange(of: viewModel.searchQuery) { oldValue, newValue in
                        viewModel.handleSearchQueryChange(oldValue: oldValue, newValue: newValue)
                    }
                
                Divider()
                
                // Tag filter
                if !viewModel.allTags.isEmpty {
                    TagFilterBar(
                        tags: viewModel.allTags,
                        selectedTag: viewModel.selectedTag,
                        onSelect: { tag in
                            Task {
                                if let tag = tag {
                                    await viewModel.loadNotesByTag(tag)
                                } else {
                                    await viewModel.clearTagFilter()
                                }
                            }
                        }
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    
                    Divider()
                }
                
                // Notes list
                if viewModel.isSearching && !viewModel.searchQuery.isEmpty {
                    SearchResultsList(
                        results: viewModel.searchResults,
                        selectedNote: $viewModel.selectedNote
                    )
                } else {
                    NotesList(
                        notes: viewModel.notes,
                        selectedNote: $viewModel.selectedNote,
                        onDelete: { note in
                            Task {
                                await viewModel.deleteNote(note)
                            }
                        }
                    )
                }
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 320)
            .toolbar {
                ToolbarItem {
                    Button(action: { showingNewNote = true }) {
                        Label("New Note", systemImage: "square.and.pencil")
                    }
                }
            }
        } detail: {
            if let note = viewModel.selectedNote {
                NoteDetailView(
                    note: note,
                    onEdit: { editingNote = note },
                    onFindRelated: {
                        Task { @MainActor in
                            relatedNotes = await viewModel.findRelated(to: note)
                            if !relatedNotes.isEmpty {
                                showingRelated = true
                            }
                        }
                    }
                )
            } else {
                EmptyStateView(
                    icon: "tray",
                    title: "No Note Selected",
                    message: "Select a note from the sidebar or create a new one"
                )
            }
        }
        .sheet(isPresented: $showingRelated) {
            RelatedNotesSheet(
                notes: relatedNotes,
                onSelect: { note in
                    viewModel.selectedNote = note
                    showingRelated = false
                }
            )
        }
        .sheet(isPresented: $showingNewNote) {
            NoteEditorSheet(
                mode: .create,
                onSave: { title, content, tags in
                    Task {
                        if let note = await viewModel.createNote(title: title, content: content, tags: tags) {
                            viewModel.selectedNote = note
                        }
                    }
                }
            )
        }
        .sheet(item: $editingNote) { note in
            NoteEditorSheet(
                mode: .edit(note),
                onSave: { title, content, tags in
                    Task {
                        if let updated = await viewModel.updateNote(note, title: title, content: content, tags: tags) {
                            viewModel.selectedNote = updated
                        }
                    }
                }
            )
        }
        .task {
            // Use Task.detached to break out of SwiftUI's view update context
            await Task.detached { @MainActor [viewModel] in
                // #region agent log
                let logPath = "/Users/gdullas/Desktop/Projects/Mneme/.cursor/debug.log"
                let logEntry = "{\"location\":\"VaultView.swift:task\",\"message\":\"Detached task starting loadNotes\",\"data\":{},\"timestamp\":\(Date().timeIntervalSince1970 * 1000),\"sessionId\":\"debug-session\",\"hypothesisId\":\"K\",\"runId\":\"post-fix-v5\"}\n"
                if let data = logEntry.data(using: .utf8), let handle = FileHandle(forWritingAtPath: logPath) { handle.seekToEndOfFile(); handle.write(data); handle.closeFile() } else { FileManager.default.createFile(atPath: logPath, contents: logEntry.data(using: .utf8)) }
                // #endregion
                
                await viewModel.loadNotes()
                await viewModel.loadTags()
            }.value
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error ?? "")
        }
        .onChange(of: viewModel.error) { _, newValue in
            // #region agent log
            let logPath = "/Users/gdullas/Desktop/Projects/Mneme/.cursor/debug.log"
            let logEntry = "{\"location\":\"VaultView.swift:143\",\"message\":\"error onChange triggered\",\"data\":{\"hasError\":\(newValue != nil)},\"timestamp\":\(Date().timeIntervalSince1970 * 1000),\"sessionId\":\"debug-session\",\"hypothesisId\":\"B\",\"runId\":\"post-fix\"}\n"
            if let data = logEntry.data(using: .utf8), let handle = FileHandle(forWritingAtPath: logPath) { handle.seekToEndOfFile(); handle.write(data); handle.closeFile() } else { FileManager.default.createFile(atPath: logPath, contents: logEntry.data(using: .utf8)) }
            // #endregion
            if newValue != nil {
                viewModel.showError = true
            }
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(.textBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Tag Filter Bar

struct TagFilterBar: View {
    let tags: [(String, Int)]
    let selectedTag: String?
    let onSelect: (String?) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                TagChip(
                    name: "All",
                    count: nil,
                    isSelected: selectedTag == nil,
                    action: { onSelect(nil) }
                )
                
                ForEach(tags.prefix(10), id: \.0) { tag, count in
                    TagChip(
                        name: tag,
                        count: count,
                        isSelected: selectedTag == tag,
                        action: { onSelect(tag) }
                    )
                }
            }
        }
    }
}

struct TagChip: View {
    let name: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.caption)
                
                if let count = count {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color(.controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notes List

struct NotesList: View {
    let notes: [Note]
    @Binding var selectedNote: Note?
    let onDelete: (Note) -> Void
    
    var body: some View {
        List(notes, selection: $selectedNote) { note in
            NoteRowView(note: note)
                .tag(note)
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        onDelete(note)
                    }
                }
        }
        .listStyle(.sidebar)
    }
}

struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.displayTitle)
                .font(.headline)
                .lineLimit(1)
            
            Text(note.preview)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            HStack(spacing: 4) {
                Text(note.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                if !note.tags.isEmpty {
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    ForEach(note.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(3)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Search Results

struct SearchResultsList: View {
    let results: [Note]
    @Binding var selectedNote: Note?
    
    var body: some View {
        if results.isEmpty {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No Results",
                message: "Try a different search query"
            )
        } else {
            List(results, selection: $selectedNote) { note in
                SearchResultRow(note: note)
                    .tag(note)
            }
            .listStyle(.sidebar)
        }
    }
}

struct SearchResultRow: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                if let similarity = note.similarity {
                    Text("\(Int(similarity * 100))%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                }
            }
            
            Text(note.preview)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Note Detail View

struct NoteDetailView: View {
    let note: Note
    let onEdit: () -> Void
    let onFindRelated: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        if let title = note.title, !title.isEmpty {
                            Text(title)
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        
                        HStack(spacing: 6) {
                            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if note.createdAt != note.updatedAt {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text("Updated \(note.updatedAt, style: .relative)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !note.tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(note.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Content
                    Text(note.content)
                        .font(.body)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                }
                .frame(maxWidth: 600)
                .padding(16)
                .frame(width: geometry.size.width, alignment: .center)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: onFindRelated) {
                    Label("Find Related", systemImage: "arrow.triangle.branch")
                }
                
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
    }
}

// MARK: - Note Editor Sheet

enum NoteEditorMode {
    case create
    case edit(Note)
}

struct NoteEditorSheet: View {
    let mode: NoteEditorMode
    let onSave: (String?, String, [String]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var tagsText: String = ""
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                
                Spacer()
                
                Text(isEditing ? "Edit Note" : "New Note")
                    .font(.headline)
                
                Spacer()
                
                Button("Save") { save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(content.isEmpty)
            }
            .padding()
            
            Divider()
            
            // Form
            Form {
                TextField("Title (optional)", text: $title)
                
                VStack(alignment: .leading) {
                    Text("Content")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $content)
                        .font(.body)
                        .frame(minHeight: 200)
                }
                
                TextField("Tags (comma-separated)", text: $tagsText)
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            if case .edit(let note) = mode {
                title = note.title ?? ""
                content = note.content
                tagsText = note.tags.joined(separator: ", ")
            }
        }
    }
    
    private func save() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        onSave(title.isEmpty ? nil : title, content, tags)
        dismiss()
    }
}

// MARK: - Related Notes Sheet

struct RelatedNotesSheet: View {
    let notes: [Note]
    let onSelect: (Note) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Related Notes")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            
            Divider()
            
            if notes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No related notes found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(notes) { note in
                    Button(action: { onSelect(note) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(note.displayTitle)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if let similarity = note.similarity {
                                    Text("\(Int(similarity * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            
                            Text(note.preview)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding()
    }
}

#Preview {
    VaultView()
}

