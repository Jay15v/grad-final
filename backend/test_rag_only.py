from services.rag_service import verify_claims_with_rag

# 🔹 Fake claims (simulate backend output)
claims = [
    {
        "claim": "The sky appears blue due to Rayleigh scattering of sunlight by air molecules",
        "source_step_id": 2
    },
    {
        "claim": "At sunset, sunlight travels a longer path through the atmosphere, scattering shorter wavelengths",
        "source_step_id": 4
    }
]

out = verify_claims_with_rag(claims)

print("\n=== RAG RESULTS ===")
for r in out:
    print("\nClaim:", r["claim"])
    print("Verdict:", r["verdict"])
    print("Top evidence count:", len(r.get("top_evidence", [])))
