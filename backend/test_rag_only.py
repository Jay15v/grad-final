from services.rag_service import verify_claims_with_rag

# --------------------------------------------------
# 1️⃣ Test claims (this simulates output from fusion)
# --------------------------------------------------
claims = [
    {
        "claim": "The sky appears blue due to Rayleigh scattering of sunlight by air molecules",
        "source_step_id": 1
    },
    {
        "claim": "At sunset, sunlight travels a longer path through the atmosphere, scattering shorter wavelengths",
        "source_step_id": 2
    }
]

# --------------------------------------------------
# 2️⃣ Run RAG verification
# --------------------------------------------------
results = verify_claims_with_rag(claims, k=5)

# --------------------------------------------------
# 3️⃣ Pretty STEP-AWARE output (what you want)
# --------------------------------------------------
print("\n=== RAG RESULTS (STEP-AWARE) ===\n")

for r in results:
    step_id = r["source_step_id"]
    claim = r["claim"]
    verdict = r["verdict"]
    best = r["best_evidence"]

    print(f"Step {step_id}: {claim}")
    print(f"Verdict: {verdict}")

    if best:
        sim = best.get("similarity", 0.0)
        cov = best.get("coverage", 0.0)

        print(f"Best Evidence (sim={sim:.2f}, cov={cov:.2f})")
        print(f"Source: {best.get('source', '')}")
        print(f"Title : {best.get('title', '')}")
        print(f"URL   : {best.get('url', '')}")
        print(f"Text  : {best.get('text', '')[:300]} ...")
    else:
        print("No evidence retrieved.")

    print("-" * 100)
