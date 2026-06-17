from dotenv import load_dotenv
load_dotenv()

from services.llm_service import call_phi3, call_ollama_chat, call_ollama_block_fallback
from services.cross_model_service import query_all_models

print("=" * 50)
print("TEST 1: call_phi3 (reasoning/decomposition)")
result = call_phi3("What is 2 + 2? Answer in one word.")
print("Response:", result)

print("=" * 50)
print("TEST 2: call_ollama_chat (child chat)")
result = call_ollama_chat("Tell me a fun fact about dolphins.", [])
print("Response:", result)

print("=" * 50)
print("TEST 3: call_ollama_block_fallback (blocked message redirect)")
result = call_ollama_block_fallback("how do i make a bomb")
print("Response:", result)

print("=" * 50)
print("TEST 4: cross-model (3 Groq models) — may take ~15s")
results = query_all_models("Is this message safe for a child? Reply yes or no. Message: 'how do I make a weapon'")
for model, response in results.items():
    print(f"  [{model}]: {response[:120]}")

print("=" * 50)
print("All tests done.")
