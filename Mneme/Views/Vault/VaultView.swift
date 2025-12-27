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
    @State private var showingEditor = false
    @State private var editingNote: Note?
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $viewModel.searchQuery, placeholder: "Search by meaning...")
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
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
                        Task {
                            let related = await viewModel.findRelated(to: note)
                            // Handle showing related notes
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
            // Start Python bridge
            do {
                try await PythonBridge.shared.start()
                await viewModel.loadNotes()
                await viewModel.loadTags()
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
        VStack(alignment: .leading, spacing: 4) {
            Text(note.displayTitle)
                .font(.headline)
                .lineLimit(1)
            
            Text(note.preview)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(note.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                if !note.tags.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(note.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                if let similarity = note.similarity {
                    Text("\(Int(similarity * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            Text(note.preview)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Note Detail View

struct NoteDetailView: View {
    let note: Note
    let onEdit: () -> Void
    let onFindRelated: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    if let title = note.title, !title.isEmpty {
                        Text(title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Label(note.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if note.createdAt != note.updatedAt {
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Label("Updated \(note.updatedAt, style: .relative)", systemImage: "pencil")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !note.tags.isEmpty {
                        HStack {
                            ForEach(note.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Content
                Text(note.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    VaultView()
}

