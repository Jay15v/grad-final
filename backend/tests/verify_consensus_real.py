"""
Real end-to-end verification for consensus_service.cross_model_validate.

Requires:
  - Ollama running locally on port 11434 with phi3, llama3, and mistral pulled.
  - SBERT model 'all-MiniLM-L6-v2' available (downloaded on first run).

Run from the backend/ directory:
    python tests/verify_consensus_real.py
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from services.consensus_service import cross_model_validate

prompt = "What is the capital of France?"
result = cross_model_validate(prompt)

print(f"Verdict:       {result['verdict']}")
print(f"Display Label: {result['display_label']}")
print(f"Avg Agreement: {result['avg_agreement']:.2f}")
print(f"Pairs:")
for pair, score in result["pairs"]:
    print(f"  {pair}: {score:.2f}")
print(f"Models responded: {list(result['responses'].keys())}")
