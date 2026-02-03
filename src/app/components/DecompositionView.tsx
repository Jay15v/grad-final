interface DecompositionStep {
  id: number;
  text: string;
  source_span?: string;
}

interface Claim {
  claim: string;
  source_step_id: number;
}

interface Decomposition {
  steps: DecompositionStep[];
  constraints: Record<string, any>;
  quality: {
    score: number;
    atomicity?: number;
    verb_rate?: number;
    redundancy?: number;
  };
}

interface DecompositionViewProps {
  decomposition: Decomposition;
  claims: Claim[];
}

export function DecompositionView({
  decomposition,
  claims,
}: DecompositionViewProps) {
  const claimsByStep = claims.reduce<Record<number, Claim[]>>(
    (acc, claim) => {
      acc[claim.source_step_id] = acc[claim.source_step_id] || [];
      acc[claim.source_step_id].push(claim);
      return acc;
    },
    {}
  );

  return (
    <section className="bg-slate-900/60 border border-cyan-500/20 rounded-xl p-6 space-y-6">
      <h2 className="text-xl font-semibold text-cyan-300">
        Prompt Decomposition
      </h2>

      {decomposition.steps.map((step) => (
        <div
          key={step.id}
          className="bg-slate-800/60 border border-slate-700 rounded-lg p-4 space-y-2"
        >
          <div className="flex items-center gap-2">
            <span className="text-cyan-400 font-semibold">
              Step {step.id}
            </span>
            <span className="text-slate-200">{step.text}</span>
          </div>

          {step.source_span && (
            <p className="text-xs text-slate-400 italic">
              Source: {step.source_span}
            </p>
          )}

          {claimsByStep[step.id] && (
            <div className="mt-3 space-y-1">
              <p className="text-sm font-medium text-emerald-400">
                Claims
              </p>
              <ul className="list-disc list-inside text-sm text-slate-300">
                {claimsByStep[step.id].map((c, i) => (
                  <li key={i}>{c.claim}</li>
                ))}
              </ul>
            </div>
          )}
        </div>
      ))}

      <div className="pt-4 text-sm text-slate-400">
        Decomposition quality score:{' '}
        <span className="text-cyan-300 font-semibold">
          {Math.round(decomposition.quality.score * 100)}%
        </span>
      </div>
    </section>
  );
}
