export interface RagEvidence {
  claim: string;
  source_step_id: number;
  verdict: "SUPPORTED_WEAK" | "WEAK" | "NO_EVIDENCE";
  best_evidence: {
    source: string;
    title: string;
    url: string;
    text: string;
    similarity: number;
    coverage?: number;
  } | null;
}
