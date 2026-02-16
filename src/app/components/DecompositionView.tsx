import { useMemo, useState } from "react";

interface DecompositionStep {
  id: number;
  text: string;
  source_span?: string;
}

interface Claim {
  claim: string;
  source_step_id: number;
}

interface RagEvidenceChunk {
  id: string;
  source: string;
  title: string;
  url: string;
  text: string;
  similarity: number;
  coverage?: number;
}

interface RagResult {
  claim: string;
  source_step_id: number;
  verdict: "SUPPORTED_WEAK" | "WEAK" | "NO_EVIDENCE";
  best_evidence?: RagEvidenceChunk | null;
  top_evidence?: RagEvidenceChunk[];
}

interface Decomposition {
  steps: DecompositionStep[];
  constraints: Record<string, any>;
  quality: { score: number };
}

interface RagEval {
  total_steps: number;
  hits: number;
  misses: number;
  hit_rate: number;
}

interface Props {
  decomposition: Decomposition;
  claims: Claim[];
  ragResults: RagResult[];
  ragEval?: RagEval;
}

/** Small helper component: truncates long text and allows expanding/collapsing */
function ExpandableText({
  text,
  initialChars = 180,
  className = "",
}: {
  text: string;
  initialChars?: number;
  className?: string;
}) {
  const [open, setOpen] = useState(false);

  const isLong = (text || "").length > initialChars;
  const shown = open || !isLong ? text : `${text.slice(0, initialChars)}…`;

  return (
    <div className={className}>
      <p className="text-slate-200 leading-relaxed whitespace-pre-wrap">{shown}</p>
      {isLong && (
        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          className="mt-2 text-xs font-semibold text-cyan-300 hover:text-cyan-200 underline"
        >
          {open ? "See less" : "See more"}
        </button>
      )}
    </div>
  );
}

export function DecompositionView({
  decomposition,
  claims,
  ragResults,
  ragEval,
}: Props) {
  // Expand/collapse ranked evidence per claim
  const [expandedRanks, setExpandedRanks] = useState<Record<string, boolean>>({});

  // Expand/collapse full ranked evidence text per chunk (unique key)
  const [expandedChunk, setExpandedChunk] = useState<Record<string, boolean>>({});

  const claimsByStep = useMemo(() => {
    return claims.reduce<Record<number, Claim[]>>((acc, c) => {
      acc[c.source_step_id] = acc[c.source_step_id] || [];
      acc[c.source_step_id].push(c);
      return acc;
    }, {});
  }, [claims]);

  const ragByStep = useMemo(() => {
    return ragResults.reduce<Record<number, RagResult[]>>((acc, r) => {
      acc[r.source_step_id] = acc[r.source_step_id] || [];
      acc[r.source_step_id].push(r);
      return acc;
    }, {});
  }, [ragResults]);

  return (
    <section className="bg-slate-900/60 border border-cyan-500/20 rounded-xl p-6 space-y-6">
      <h2 className="text-xl font-semibold text-cyan-300">Prompt Decomposition</h2>

      {/* ================= RAG HIT/MISS SUMMARY ================= */}
      {ragEval && (
        <div className="rounded-xl border border-white/10 bg-white/5 p-4">
          <div className="font-semibold mb-2 text-cyan-300">RAG Hit/Miss Evaluation</div>

          <div className="flex flex-wrap gap-6 text-sm text-slate-100">
            <div>
              <span className="font-semibold text-slate-50">Claims:</span>{" "}
              <span className="text-cyan-200 font-semibold">{ragEval.total_steps}</span>
            </div>

            <div>
              <span className="font-semibold text-slate-50">Hits:</span>{" "}
              <span className="text-emerald-300 font-semibold">{ragEval.hits}</span>
            </div>

            <div>
              <span className="font-semibold text-slate-50">Misses:</span>{" "}
              <span className="text-rose-300 font-semibold">{ragEval.misses}</span>
            </div>

            <div>
              <span className="font-semibold text-slate-50">Hit rate:</span>{" "}
              <span className="text-cyan-200 font-semibold">
                {(ragEval.hit_rate * 100).toFixed(1)}%
              </span>
            </div>
          </div>
        </div>
      )}

      {/* ================= STEPS ================= */}
      {decomposition.steps.map((step) => (
        <div
          key={step.id}
          className="bg-slate-800/60 border border-slate-700 rounded-lg p-4 space-y-4"
        >
          {/* Step Header */}
          <div>
            <span className="text-cyan-300 font-semibold">Step {step.id}</span>
            <p className="text-slate-100 mt-1">{step.text}</p>
          </div>

          {/* Claims */}
          {claimsByStep[step.id] && (
            <div>
              <p className="text-emerald-300 font-medium">Claims</p>
              <ul className="list-disc list-inside text-sm text-slate-200">
                {claimsByStep[step.id].map((c, i) => (
                  <li key={i} className="leading-relaxed">
                    {c.claim}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* RAG Verification */}
          {ragByStep[step.id] && (
            <div className="border-t border-slate-700 pt-3 space-y-4">
              <p className="text-cyan-300 font-semibold">RAG Verification</p>

              {ragByStep[step.id].map((r, i) => {
                const claimKey = `${step.id}::${r.claim}`;
                const ranksOpen = !!expandedRanks[claimKey];

                return (
                  <div
                    key={i}
                    className="bg-slate-900/60 border border-slate-700 rounded-md p-4 text-sm space-y-3"
                  >
                    {/* Verdict */}
                    <p className="text-slate-100">
                      <strong>Verdict:</strong>{" "}
                      <span
                        className={
                          r.verdict === "SUPPORTED_WEAK"
                            ? "text-emerald-300"
                            : r.verdict === "WEAK"
                            ? "text-amber-300"
                            : "text-rose-300"
                        }
                      >
                        {r.verdict}
                      </span>
                    </p>

                    {/* BEST EVIDENCE */}
                    {r.best_evidence ? (
                      <div className="space-y-2 text-slate-100">
                        <p>
                          <strong>Best Source:</strong>{" "}
                          <span className="text-slate-200">{r.best_evidence.source}</span>
                        </p>
                        <p>
                          <strong>Title:</strong>{" "}
                          <span className="text-slate-200">{r.best_evidence.title}</span>
                        </p>

                        <div className="flex flex-wrap gap-4">
                          <p>
                            <strong>Similarity:</strong>{" "}
                            <span className="text-cyan-200">
                              {r.best_evidence.similarity.toFixed(2)}
                            </span>
                          </p>

                          {typeof r.best_evidence.coverage === "number" && (
                            <p>
                              <strong>Coverage:</strong>{" "}
                              <span className="text-cyan-200">
                                {r.best_evidence.coverage.toFixed(2)}
                              </span>
                            </p>
                          )}
                        </div>

                        <a
                          href={r.best_evidence.url}
                          target="_blank"
                          rel="noreferrer"
                          className="text-cyan-300 hover:text-cyan-200 underline font-semibold"
                        >
                          View Source
                        </a>

                        <ExpandableText
                          text={r.best_evidence.text}
                          initialChars={220}
                          className="mt-2"
                        />
                      </div>
                    ) : (
                      <p className="italic text-slate-300">No evidence retrieved.</p>
                    )}

                    {/* COLLAPSIBLE RANKED EVIDENCE */}
                    {r.top_evidence && r.top_evidence.length > 0 && (
                      <div className="pt-1">
                        <button
                          type="button"
                          onClick={() =>
                            setExpandedRanks((prev) => ({
                              ...prev,
                              [claimKey]: !prev[claimKey],
                            }))
                          }
                          className="text-xs font-semibold text-cyan-300 hover:text-cyan-200 underline"
                        >
                          {ranksOpen ? "Hide Ranked Evidence" : "Show Top Ranked Evidence"}
                        </button>

                        {ranksOpen && (
                          <div className="mt-3 border-t border-slate-700 pt-3 space-y-3">
                            {r.top_evidence.map((chunk, idx) => {
                              const chunkKey = `${claimKey}::${chunk.id}`;
                              const chunkOpen = !!expandedChunk[chunkKey];
                              const isLong = (chunk.text || "").length > 180;

                              const shown = chunkOpen || !isLong
                                ? chunk.text
                                : `${chunk.text.slice(0, 180)}…`;

                              return (
                                <div
                                  key={chunk.id}
                                  className="bg-slate-800/70 border border-slate-700 p-3 rounded-md text-xs space-y-2"
                                >
                                  <p className="font-semibold text-cyan-200">Rank {idx + 1}</p>

                                  <div className="flex flex-wrap gap-4 text-slate-100">
                                    <p>
                                      <strong>Similarity:</strong>{" "}
                                      <span className="text-cyan-200">
                                        {chunk.similarity.toFixed(2)}
                                      </span>
                                    </p>

                                    {typeof chunk.coverage === "number" && (
                                      <p>
                                        <strong>Coverage:</strong>{" "}
                                        <span className="text-cyan-200">
                                          {chunk.coverage.toFixed(2)}
                                        </span>
                                      </p>
                                    )}
                                  </div>

                                  {/* Chunk text + see more */}
                                  <p className="text-slate-200 leading-relaxed whitespace-pre-wrap">
                                    {shown}
                                  </p>

                                  {isLong && (
                                    <button
                                      type="button"
                                      onClick={() =>
                                        setExpandedChunk((prev) => ({
                                          ...prev,
                                          [chunkKey]: !prev[chunkKey],
                                        }))
                                      }
                                      className="text-xs font-semibold text-cyan-300 hover:text-cyan-200 underline"
                                    >
                                      {chunkOpen ? "See less" : "See more"}
                                    </button>
                                  )}
                                </div>
                              );
                            })}
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      ))}

      {/* Quality Score */}
      <div className="text-sm text-slate-200 pt-4">
        Decomposition quality score:{" "}
        <span className="text-cyan-200 font-semibold">
          {Math.round(decomposition.quality.score * 100)}%
        </span>
      </div>
    </section>
  );
}
