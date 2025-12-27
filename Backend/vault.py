"""
Mneme Knowledge Vault
Core API for notes, search, and retrieval
"""
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime

import database as db
from embeddings import get_embedding_engine, auto_tag


class KnowledgeVault:
    """
    The Knowledge Vault - your personal semantic knowledge base.
    """
    
    def __init__(self):
        self.embedding_engine = get_embedding_engine()
    
    # ─────────────────────────────────────────────────────────────────────────
    # Note Operations
    # ─────────────────────────────────────────────────────────────────────────
    
    def create_note(self, content: str, title: Optional[str] = None,
                   tags: Optional[List[str]] = None,
                   auto_generate_tags: bool = True) -> Dict[str, Any]:
        """
        Create a new note in the vault.
        
        The note will be automatically embedded for semantic search.
        Optionally auto-generates tags based on content.
        """
        # Generate embedding
        embedding = self.embedding_engine.embed(content)
        
        # Auto-tag if requested
        final_tags = list(tags) if tags else []
        suggested_tags = []
        
        if auto_generate_tags:
            auto_tags = auto_tag(content)
            suggested_tags = [tag for tag, _ in auto_tags]
            # Add auto-tags that aren't already present
            for tag, confidence in auto_tags:
                if tag not in final_tags:
                    final_tags.append(tag)
        
        # Create in database
        note_id = db.create_note(
            title=title,
            content=content,
            tags=final_tags,
            embedding=embedding
        )
        
        # Return the created note
        note = db.get_note(note_id)
        note['suggested_tags'] = suggested_tags
        
        return note
    
    def update_note(self, note_id: int, content: Optional[str] = None,
                   title: Optional[str] = None,
                   tags: Optional[List[str]] = None) -> Dict[str, Any]:
        """Update an existing note. Re-embeds if content changes."""
        embedding = None
        if content:
            embedding = self.embedding_engine.embed(content)
        
        db.update_note(
            note_id=note_id,
            title=title,
            content=content,
            tags=tags,
            embedding=embedding
        )
        
        return db.get_note(note_id)
    
    def get_note(self, note_id: int) -> Optional[Dict[str, Any]]:
        """Get a specific note by ID."""
        return db.get_note(note_id)
    
    def get_all_notes(self, limit: int = 100, offset: int = 0) -> List[Dict[str, Any]]:
        """Get all notes, ordered by most recently updated."""
        return db.get_all_notes(limit=limit, offset=offset)
    
    def delete_note(self, note_id: int):
        """Delete a note from the vault."""
        db.delete_note(note_id)
    
    # ─────────────────────────────────────────────────────────────────────────
    # Semantic Search
    # ─────────────────────────────────────────────────────────────────────────
    
    def search(self, query: str, limit: int = 10,
               min_similarity: float = 0.0) -> List[Dict[str, Any]]:
        """
        Search notes by meaning using natural language.
        
        Examples:
            vault.search("ideas about career change")
            vault.search("thoughts on burnout")
            vault.search("things I'm grateful for")
        """
        # Get all embeddings
        embeddings = db.get_notes_with_embeddings()
        
        if not embeddings:
            return []
        
        # Perform semantic search
        results = self.embedding_engine.search(query, embeddings, top_k=limit * 2)
        
        # Filter by minimum similarity and fetch full notes
        notes = []
        for note_id, similarity in results:
            if similarity >= min_similarity:
                note = db.get_note(note_id)
                if note:
                    note['similarity'] = similarity
                    notes.append(note)
                    if len(notes) >= limit:
                        break
        
        return notes
    
    def find_related(self, note_id: int, limit: int = 5) -> List[Dict[str, Any]]:
        """Find notes related to a specific note."""
        note = db.get_note(note_id)
        if not note:
            return []
        
        # Search using the note's content
        results = self.search(note.get('content', ''), limit=limit + 1)
        
        # Filter out the source note
        return [r for r in results if r['id'] != note_id][:limit]
    
    # ─────────────────────────────────────────────────────────────────────────
    # Tag Operations
    # ─────────────────────────────────────────────────────────────────────────
    
    def get_notes_by_tag(self, tag: str) -> List[Dict[str, Any]]:
        """Get all notes with a specific tag."""
        all_notes = db.get_all_notes(limit=1000)
        return [n for n in all_notes if tag in n.get('tags', [])]
    
    def get_all_tags(self) -> List[Tuple[str, int]]:
        """Get all tags and their counts."""
        all_notes = db.get_all_notes(limit=10000)
        tag_counts = {}
        
        for note in all_notes:
            for tag in note.get('tags', []):
                tag_counts[tag] = tag_counts.get(tag, 0) + 1
        
        return sorted(tag_counts.items(), key=lambda x: x[1], reverse=True)


# Singleton instance
_vault: Optional[KnowledgeVault] = None


def get_vault() -> KnowledgeVault:
    """Get the singleton vault instance."""
    global _vault
    if _vault is None:
        _vault = KnowledgeVault()
    return _vault

