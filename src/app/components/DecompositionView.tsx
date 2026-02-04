interface DecompositionStep {
  id: number;
  text: string;
  source_span?: string;
}

interface Claim {
  claim: string;
  source_step_id: number;
}

interface RagResult {
  claim: string;
  source_step_id: number;
  verdict: "SUPPORTED_WEAK" | "WEAK" | "NO_EVIDENCE";
  best_evidence?: {
    source: string;
    title: string;
    url: string;
    text: string;
    similarity: number;
    coverage?: number;
  } | null;
}

interface Decomposition {
  steps: DecompositionStep[];
  constraints: Record<string, any>;
  quality: { score: number };
}

interface Props {
  decomposition: Decomposition;
  claims: Claim[];
  ragResults: RagResult[];
}

export function DecompositionView({
  decomposition,
  claims,
  ragResults,
}: Props) {
  const claimsByStep = claims.reduce<Record<number, Claim[]>>((acc, c) => {
    acc[c.source_step_id] = acc[c.source_step_id] || [];
    acc[c.source_step_id].push(c);
    return acc;
  }, {});

  const ragByStep = ragResults.reduce<Record<number, RagResult[]>>((acc, r) => {
    acc[r.source_step_id] = acc[r.source_step_id] || [];
    acc[r.source_step_id].push(r);
    return acc;
  }, {});

  return (
    <section className="bg-slate-900/60 border border-cyan-500/20 rounded-xl p-6 space-y-6">
      <h2 className="text-xl font-semibold text-cyan-300">
        Prompt Decomposition
      </h2>

      {decomposition.steps.map(step => (
        <div
          key={step.id}
          className="bg-slate-800/60 border border-slate-700 rounded-lg p-4 space-y-4"
        >
          <div>
            <span className="text-cyan-400 font-semibold">
              Step {step.id}
            </span>
            <p className="text-slate-200 mt-1">{step.text}</p>
          </div>

          {claimsByStep[step.id] && (
            <div>
              <p className="text-emerald-400 font-medium">Claims</p>
              <ul className="list-disc list-inside text-sm text-slate-300">
                {claimsByStep[step.id].map((c, i) => (
                  <li key={i}>{c.claim}</li>
                ))}
              </ul>
            </div>
          )}

          {ragByStep[step.id] && (
            <div className="border-t border-slate-700 pt-3 space-y-3">
              <p className="text-cyan-400 font-semibold">
                RAG Verification
              </p>

              {ragByStep[step.id].map((r, i) => (
                <div
                  key={i}
                  className="bg-slate-900 border border-slate-700 rounded-md p-3 text-sm"
                >
                  <p>
                    <strong>Verdict:</strong>{" "}
                    <span
                      className={
                        r.verdict === "SUPPORTED_WEAK"
                          ? "text-emerald-400"
                          : r.verdict === "WEAK"
                          ? "text-yellow-400"
                          : "text-red-400"
                      }
                    >
                      {r.verdict}
                    </span>
                  </p>

                  {r.best_evidence ? (
                    <div className="mt-2 text-slate-300 space-y-1">
                      <p><strong>Source:</strong> {r.best_evidence.source}</p>
                      <p><strong>Title:</strong> {r.best_evidence.title}</p>
                      <p>
                        <strong>Similarity:</strong>{" "}
                        {r.best_evidence.similarity.toFixed(2)}
                      </p>
                      <a
                        href={r.best_evidence.url}
                        target="_blank"
                        rel="noreferrer"
                        className="text-cyan-400 underline"
                      >
                        View Source
                      </a>
                      <p className="italic text-xs mt-1">
                        {r.best_evidence.text.slice(0, 280)}…
                      </p>
                    </div>
                  ) : (
                    <p className="italic text-slate-400 mt-2">
                      No evidence retrieved.
                    </p>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      ))}

      <div className="text-sm text-slate-400 pt-4">
        Decomposition quality score:{" "}
        <span className="text-cyan-300 font-semibold">
          {Math.round(decomposition.quality.score * 100)}%
        </span>
      </div>
    </section>
  );
}
