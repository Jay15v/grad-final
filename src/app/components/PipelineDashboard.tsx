import { useEffect, useRef, useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import {
  Shield,
  GitBranch,
  Brain,
  Search,
  CheckCircle,
  XCircle,
  AlertCircle,
  Loader2,
  ChevronDown,
  ChevronUp,
  ShieldOff,
  AlertTriangle,
} from "lucide-react";
import type { DefenseMeta } from "./ChatPanel";

/* ---------- Types ---------- */

interface StageEntry {
  status: "running" | "done";
  data?: any;
  error?: string;
}

interface PipelineState {
  status: "idle" | "running" | "done" | "error";
  stages: {
    decomposition?: StageEntry;
    reasoning?: StageEntry;
    claims?: StageEntry;
    rag?: StageEntry;
  };
}

interface PipelineDashboardProps {
  pipelineId: string | null;
  defenseMeta: DefenseMeta | null;
}

/* ---------- Helpers ---------- */

function riskColor(risk: number) {
  if (risk >= 0.6) return "text-red-400";
  if (risk >= 0.35) return "text-yellow-400";
  return "text-green-400";
}

function riskBar(risk: number) {
  const pct = Math.round(risk * 100);
  const color = risk >= 0.6 ? "bg-red-500" : risk >= 0.35 ? "bg-yellow-500" : "bg-green-500";
  return { pct, color };
}

/* ---------- Stage Card ---------- */

function StageCard({
  title,
  icon: Icon,
  stage,
  children,
}: {
  title: string;
  icon: React.ElementType;
  stage?: StageEntry;
  children?: (data: any) => React.ReactNode;
}) {
  const [expanded, setExpanded] = useState(true);
  const isRunning = stage?.status === "running";
  const isDone = stage?.status === "done";
  const isIdle = !stage;

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      className="rounded-xl border border-slate-700/40 bg-slate-900/60 overflow-hidden"
    >
      <button
        onClick={() => setExpanded((v) => !v)}
        className="w-full flex items-center gap-2 px-3 py-2.5 hover:bg-slate-800/40 transition-colors"
      >
        <Icon className={`w-4 h-4 flex-shrink-0 ${isDone ? "text-cyan-400" : isRunning ? "text-yellow-400" : "text-slate-500"}`} />
        <span className="text-sm font-medium text-white flex-1 text-left">{title}</span>
        {isRunning && <Loader2 className="w-3.5 h-3.5 text-yellow-400 animate-spin" />}
        {isDone && <CheckCircle className="w-3.5 h-3.5 text-green-400" />}
        {isIdle && <span className="text-xs text-slate-600">waiting</span>}
        {expanded ? (
          <ChevronUp className="w-3.5 h-3.5 text-slate-500 ml-1" />
        ) : (
          <ChevronDown className="w-3.5 h-3.5 text-slate-500 ml-1" />
        )}
      </button>

      <AnimatePresence initial={false}>
        {expanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="overflow-hidden"
          >
            <div className="px-3 pb-3 pt-1 border-t border-slate-700/30">
              {isRunning && (
                <div className="flex items-center gap-2 text-xs text-yellow-400/70 py-1">
                  <Loader2 className="w-3 h-3 animate-spin" />
                  Processing...
                </div>
              )}
              {isDone && stage.data && children && (
                <div className="mt-1">{children(stage.data)}</div>
              )}
              {isDone && stage.error && (
                <p className="text-xs text-red-400 mt-1">Error: {stage.error}</p>
              )}
              {isIdle && (
                <p className="text-xs text-slate-600 py-1">Will run after defense check passes.</p>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

/* ---------- Defense Check Card ---------- */

function DefenseCard({ meta }: { meta: DefenseMeta }) {
  const isBlock = meta.decision === "BLOCK";
  const isHesitate = meta.decision === "HESITATE";
  const { pct, color } = riskBar(meta.final_risk);

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      className={`rounded-xl border p-3 ${
        isBlock
          ? "border-red-500/40 bg-red-900/20"
          : isHesitate
          ? "border-yellow-500/40 bg-yellow-900/20"
          : "border-green-500/30 bg-green-900/10"
      }`}
    >
      <div className="flex items-center gap-2 mb-2">
        {isBlock ? (
          <ShieldOff className="w-4 h-4 text-red-400" />
        ) : isHesitate ? (
          <AlertTriangle className="w-4 h-4 text-yellow-400" />
        ) : (
          <Shield className="w-4 h-4 text-green-400" />
        )}
        <span className="text-sm font-semibold text-white">Defense Check</span>
        <span
          className={`ml-auto text-xs font-bold px-2 py-0.5 rounded-full ${
            isBlock
              ? "bg-red-500/20 text-red-300"
              : isHesitate
              ? "bg-yellow-500/20 text-yellow-300"
              : "bg-green-500/20 text-green-300"
          }`}
        >
          {meta.decision}
        </span>
      </div>

      {/* Risk bar */}
      <div className="mb-2">
        <div className="flex justify-between text-[10px] text-slate-400 mb-1">
          <span>Final Risk</span>
          <span className={riskColor(meta.final_risk)}>{pct}%</span>
        </div>
        <div className="h-1.5 bg-slate-700/50 rounded-full overflow-hidden">
          <motion.div
            initial={{ width: 0 }}
            animate={{ width: `${pct}%` }}
            transition={{ duration: 0.6, ease: "easeOut" }}
            className={`h-full rounded-full ${color}`}
          />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-[10px]">
        <div className="flex justify-between">
          <span className="text-slate-500">BERT</span>
          <span className={riskColor(meta.bert_risk)}>{Math.round(meta.bert_risk * 100)}%</span>
        </div>
        <div className="flex justify-between">
          <span className="text-slate-500">Semantic</span>
          <span className="text-slate-300">{Math.round(meta.semantic_similarity * 100)}%</span>
        </div>
        <div className="col-span-2 flex justify-between">
          <span className="text-slate-500">Domain</span>
          <span className="text-slate-300 capitalize">{(meta.semantic_domain ?? "").replace(/_/g, " ")}</span>
        </div>
      </div>
    </motion.div>
  );
}

/* ---------- Main Component ---------- */

export function PipelineDashboard({ pipelineId, defenseMeta }: PipelineDashboardProps) {
  const [pipeline, setPipeline] = useState<PipelineState>({ status: "idle", stages: {} });
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const lastIdRef = useRef<string | null>(null);

  useEffect(() => {
    if (intervalRef.current) clearInterval(intervalRef.current);

    if (!pipelineId || pipelineId.startsWith("blocked-")) {
      setPipeline({ status: "idle", stages: {} });
      return;
    }

    lastIdRef.current = pipelineId;
    setPipeline({ status: "running", stages: {} });

    const poll = async () => {
      if (lastIdRef.current !== pipelineId) return;
      try {
        const res = await fetch(`http://127.0.0.1:5000/api/pipeline/${pipelineId}`);
        if (!res.ok) return;
        const data: PipelineState = await res.json();
        setPipeline(data);
        if (data.status === "done" || data.status === "error") {
          if (intervalRef.current) clearInterval(intervalRef.current);
        }
      } catch {
        /* ignore network hiccups */
      }
    };

    poll();
    intervalRef.current = setInterval(poll, 1500);

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [pipelineId]);

  const isBlocked = defenseMeta?.decision === "BLOCK";

  return (
    <div className="flex flex-col w-[55%] h-full bg-slate-950/30">
      {/* Header */}
      <div className="px-4 py-3 border-b border-slate-700/40 flex items-center gap-2 flex-shrink-0">
        <Shield className="w-4 h-4 text-cyan-400" />
        <span className="text-white font-semibold text-sm">Defense Dashboard</span>
        {pipeline.status === "running" && (
          <div className="ml-auto flex items-center gap-1.5 text-xs text-yellow-400">
            <Loader2 className="w-3 h-3 animate-spin" />
            <span>Running pipeline...</span>
          </div>
        )}
        {pipeline.status === "done" && (
          <div className="ml-auto flex items-center gap-1.5 text-xs text-green-400">
            <CheckCircle className="w-3 h-3" />
            <span>Complete</span>
          </div>
        )}
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
        {/* Empty state */}
        {!defenseMeta && (
          <div className="flex flex-col items-center justify-center h-full text-center py-16">
            <Shield className="w-14 h-14 text-slate-700 mb-4" />
            <p className="text-slate-500 text-sm font-medium">Defense pipeline</p>
            <p className="text-slate-600 text-xs mt-1">Send a message to see real-time analysis</p>
          </div>
        )}

        {/* Defense check result */}
        {defenseMeta && <DefenseCard meta={defenseMeta} />}

        {/* Pipeline stages — only if not blocked */}
        {defenseMeta && !isBlocked && (
          <>
            <StageCard title="Decomposition" icon={GitBranch} stage={pipeline.stages.decomposition}>
              {(data) => (
                <ul className="space-y-1.5">
                  {(data.steps || []).map((step: any) => (
                    <li key={step.id} className="flex gap-2 text-xs">
                      <span className="text-cyan-400 font-mono flex-shrink-0">{step.id}.</span>
                      <span className="text-slate-300">{step.text}</span>
                    </li>
                  ))}
                  {data.quality?.score !== undefined && (
                    <li className="text-[10px] text-slate-500 pt-1 border-t border-slate-700/30">
                      Quality score: {Math.round(data.quality.score * 100)}%
                    </li>
                  )}
                </ul>
              )}
            </StageCard>

            <StageCard title="Reasoning" icon={Brain} stage={pipeline.stages.reasoning}>
              {(data) => (
                <div className="space-y-2">
                  {(Array.isArray(data) ? data : []).map((item: any) => (
                    <div key={item.step_id} className="text-xs">
                      <span className="text-cyan-400 font-medium">Step {item.step_id} — </span>
                      <span className="text-slate-300">
                        {item.reasoning
                          ? item.reasoning.slice(0, 220) + (item.reasoning.length > 220 ? "…" : "")
                          : <em className="text-slate-500">No reasoning generated</em>}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </StageCard>

            <StageCard title="RAG Verification" icon={Search} stage={pipeline.stages.rag}>
              {(data) => {
                const results: any[] = data.results || [];
                const eval_ = data.rag_eval || {};
                return (
                  <div className="space-y-1.5">
                    {results.slice(0, 6).map((r: any, i: number) => (
                      <div key={i} className="flex items-start gap-2 text-xs">
                        {r.verdict === "SUPPORTED_WEAK" ? (
                          <CheckCircle className="w-3.5 h-3.5 text-green-400 mt-0.5 flex-shrink-0" />
                        ) : r.verdict === "NO_EVIDENCE" ? (
                          <XCircle className="w-3.5 h-3.5 text-red-400 mt-0.5 flex-shrink-0" />
                        ) : (
                          <AlertCircle className="w-3.5 h-3.5 text-yellow-400 mt-0.5 flex-shrink-0" />
                        )}
                        <div>
                          <span className="text-slate-300">
                            {r.claim ? r.claim.slice(0, 120) + (r.claim.length > 120 ? "…" : "") : ""}
                          </span>
                          {r.best_evidence?.source && (
                            <span className="block text-[10px] text-slate-500 mt-0.5">
                              Source: {r.best_evidence.source}
                            </span>
                          )}
                        </div>
                      </div>
                    ))}
                    {results.length === 0 && (
                      <p className="text-xs text-slate-500 italic">No claims to verify (RAG disabled or no claims extracted).</p>
                    )}
                    {eval_.total_steps > 0 && (
                      <div className="mt-2 pt-2 border-t border-slate-700/30 text-[10px] text-slate-400 flex gap-3">
                        <span>Total: {eval_.total_steps}</span>
                        <span className="text-green-400">Hits: {eval_.hits}</span>
                        <span className="text-red-400">Misses: {eval_.misses}</span>
                        <span>Rate: {Math.round((eval_.hit_rate || 0) * 100)}%</span>
                      </div>
                    )}
                  </div>
                );
              }}
            </StageCard>
          </>
        )}

        {/* Blocked state — no pipeline stages */}
        {defenseMeta && isBlocked && (
          <div className="rounded-xl border border-red-500/20 bg-red-900/10 p-4 text-center">
            <ShieldOff className="w-8 h-8 text-red-400 mx-auto mb-2" />
            <p className="text-red-300 text-sm font-medium">Message Blocked</p>
            <p className="text-red-400/60 text-xs mt-1">RAG & reasoning pipeline only runs for allowed messages.</p>
          </div>
        )}
      </div>
    </div>
  );
}
