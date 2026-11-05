#!/usr/bin/env python3
"""Byte-level invariant requested for the canonical questionnaire."""
import hashlib
import json
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "assets/data/birth_plan_flow.json"
raw = path.read_bytes()
expected = "9dbc0ceebb6b507df1c5d15a812ddbb689fe2935e4ba8c8e9637f8de0d4678dd"
if hashlib.sha256(raw).hexdigest() != expected:
    raise SystemExit("Canonical questionnaire bytes changed; explicit content authorization required.")
questions = json.loads(raw)
if len(questions) != 31 or len({q['id'] for q in questions}) != 31:
    raise SystemExit("Expected 31 unique canonical questions.")
print("31 canonical questions: original bytes and SHA-256 preserved.")
