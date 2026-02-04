import { RagEvidence } from "../types/rag";

interface Props {
  ragResults: RagEvidence[];
  stepId: number;
}

export function RagEvidenceView({ ragResults, stepId }: Props) {
  const result = ragResults.find(
    (r) => r.source_step_id === stepId
  );

  if (!result) return null;

  return (
    <div className="mt-4 rounded-lg border border-slate-700 bg-slate-900/70 p-4 space-y-2">
      <div className="text-sm font-semibold text-cyan-400">
        RAG Verification
      </div>

      <div className="text-sm">
        <strong>Verdict:</strong>{" "}
        <span
          className={
            result.verdict === "SUPPORTED_WEAK"
              ? "text-emerald-400"
              : result.verdict === "WEAK"
              ? "text-yellow-400"
              : "text-red-400"
          }
        >
          {result.verdict}
        </span>
      </div>

      {!result.best_evidence && (
        <p className="text-slate-400 italic">
          No evidence retrieved.
        </p>
      )}

      {result.best_evidence && (
        <div className="text-sm space-y-1 text-slate-300">
          <p>
            <strong>Source:</strong> {result.best_evidence.source}
          </p>
          <p>
            <strong>Title:</strong> {result.best_evidence.title}
          </p>
          <p>
            <strong>Similarity:</strong>{" "}
            {result.best_evidence.similarity.toFixed(2)}
            {result.best_evidence.coverage !== undefined && (
              <>
                {" "} | <strong>Coverage:</strong>{" "}
                {result.best_evidence.coverage.toFixed(2)}
              </>
            )}
          </p>

          <a
            href={result.best_evidence.url}
            target="_blank"
            rel="noreferrer"
            className="text-cyan-400 underline"
          >
            View source
          </a>

          <p className="italic text-xs mt-1">
            {result.best_evidence.text.slice(0, 260)}…
          </p>
        </div>
      )}
    </div>
  );
}
