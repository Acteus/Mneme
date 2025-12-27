#!/usr/bin/env python3
"""
Mneme Process Bridge
JSON-based communication between Swift and Python

Protocol:
- Swift sends JSON requests via stdin (one per line)
- Python responds with JSON via stdout (one per line)
- Each request has: {"action": "...", "params": {...}}
- Each response has: {"success": true/false, "data": ..., "error": ...}
"""
import sys
import json
import traceback
from typing import Any, Dict

# Import Mneme modules
import database as db
from vault import get_vault
from decision_simulator import run_decision_simulation
from config import DEFAULT_SIMULATION_RUNS


def handle_request(request: Dict[str, Any]) -> Dict[str, Any]:
    """Process a single request and return a response."""
    action = request.get("action")
    params = request.get("params", {})
    
    try:
        # ─────────────────────────────────────────────────────────────────────
        # Knowledge Vault Actions
        # ─────────────────────────────────────────────────────────────────────
        
        if action == "vault.create_note":
            vault = get_vault()
            note = vault.create_note(
                content=params["content"],
                title=params.get("title"),
                tags=params.get("tags"),
                auto_generate_tags=params.get("auto_generate_tags", True)
            )
            return success(note)
        
        elif action == "vault.update_note":
            vault = get_vault()
            note = vault.update_note(
                note_id=params["note_id"],
                content=params.get("content"),
                title=params.get("title"),
                tags=params.get("tags")
            )
            return success(note)
        
        elif action == "vault.get_note":
            vault = get_vault()
            note = vault.get_note(params["note_id"])
            if note:
                return success(note)
            return error("Note not found")
        
        elif action == "vault.get_all_notes":
            vault = get_vault()
            notes = vault.get_all_notes(
                limit=params.get("limit", 100),
                offset=params.get("offset", 0)
            )
            return success({"notes": notes, "count": len(notes)})
        
        elif action == "vault.delete_note":
            vault = get_vault()
            vault.delete_note(params["note_id"])
            return success({"deleted": True})
        
        elif action == "vault.search":
            vault = get_vault()
            results = vault.search(
                query=params["query"],
                limit=params.get("limit", 10),
                min_similarity=params.get("min_similarity", 0.0)
            )
            return success({"results": results, "count": len(results)})
        
        elif action == "vault.find_related":
            vault = get_vault()
            related = vault.find_related(
                note_id=params["note_id"],
                limit=params.get("limit", 5)
            )
            return success({"related": related, "count": len(related)})
        
        elif action == "vault.get_notes_by_tag":
            vault = get_vault()
            notes = vault.get_notes_by_tag(params["tag"])
            return success({"notes": notes, "count": len(notes)})
        
        elif action == "vault.get_all_tags":
            vault = get_vault()
            tags = vault.get_all_tags()
            return success({"tags": [{"name": t, "count": c} for t, c in tags]})
        
        # ─────────────────────────────────────────────────────────────────────
        # Decision Simulator Actions
        # ─────────────────────────────────────────────────────────────────────
        
        elif action == "decision.create":
            decision_id = db.create_decision(
                title=params["title"],
                description=params.get("description")
            )
            decision = db.get_decision(decision_id)
            return success(decision)
        
        elif action == "decision.get":
            decision = db.get_decision(params["decision_id"])
            if decision:
                return success(decision)
            return error("Decision not found")
        
        elif action == "decision.get_all":
            decisions = db.get_all_decisions(
                status=params.get("status")
            )
            return success({"decisions": decisions, "count": len(decisions)})
        
        elif action == "decision.delete":
            db.delete_decision(params["decision_id"])
            return success({"deleted": True})
        
        elif action == "decision.add_choice":
            choice_id = db.add_choice(
                decision_id=params["decision_id"],
                name=params["name"],
                description=params.get("description")
            )
            return success({"choice_id": choice_id})
        
        elif action == "decision.add_factor":
            factor_id = db.add_factor(
                decision_id=params["decision_id"],
                name=params["name"],
                weight=params.get("weight", 1.0),
                description=params.get("description")
            )
            return success({"factor_id": factor_id})
        
        elif action == "decision.set_score":
            db.set_score(
                choice_id=params["choice_id"],
                factor_id=params["factor_id"],
                score=params["score"],
                uncertainty=params.get("uncertainty", 0.0),
                notes=params.get("notes")
            )
            return success({"updated": True})
        
        elif action == "decision.simulate":
            decision = db.get_decision(params["decision_id"])
            if not decision:
                return error("Decision not found")
            
            results = run_decision_simulation(
                decision,
                num_runs=params.get("num_runs", DEFAULT_SIMULATION_RUNS)
            )
            
            # Optionally save results
            if params.get("save_results", False):
                db.save_simulation_result(
                    params["decision_id"],
                    results["num_simulations"],
                    results
                )
            
            return success(results)
        
        # ─────────────────────────────────────────────────────────────────────
        # System Actions
        # ─────────────────────────────────────────────────────────────────────
        
        elif action == "ping":
            return success({"status": "ok", "message": "Mneme backend is running"})
        
        elif action == "shutdown":
            return success({"status": "shutting_down"})
        
        else:
            return error(f"Unknown action: {action}")
    
    except KeyError as e:
        return error(f"Missing required parameter: {e}")
    except Exception as e:
        return error(f"{type(e).__name__}: {str(e)}", traceback.format_exc())


def success(data: Any) -> Dict[str, Any]:
    """Create a success response."""
    return {"success": True, "data": data}


def error(message: str, details: str = None) -> Dict[str, Any]:
    """Create an error response."""
    response = {"success": False, "error": message}
    if details:
        response["details"] = details
    return response


def main():
    """Main loop: read JSON from stdin, write JSON to stdout."""
    # Disable buffering for real-time communication
    sys.stdout.reconfigure(line_buffering=True)
    
    # Signal that we're ready
    print(json.dumps({"ready": True}), flush=True)
    
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        
        try:
            request = json.loads(line)
        except json.JSONDecodeError as e:
            response = error(f"Invalid JSON: {e}")
            print(json.dumps(response), flush=True)
            continue
        
        response = handle_request(request)
        print(json.dumps(response), flush=True)
        
        # Check for shutdown
        if request.get("action") == "shutdown":
            break


if __name__ == "__main__":
    main()

