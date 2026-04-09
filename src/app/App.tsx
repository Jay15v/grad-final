import { useState } from "react";
import { Footer } from "./components/Footer";
import { HeroSection } from "./components/HeroSection";
import { DefensePipeline } from "./components/DefensePipeline";
import { DecisionOutput } from "./components/DecisionOutput";
import { ActionControls } from "./components/ActionControls";
import { NotificationToast } from "./components/NotificationToast";
import { DecompositionView } from "./components/DecompositionView";
import { ChatPanel } from "./components/ChatPanel";
import { PipelineDashboard } from "./components/PipelineDashboard";
import { motion } from "motion/react";
import { RagEvidence } from "./types/rag";
import type { DefenseMeta } from "./components/ChatPanel";
import { MessageSquare, ScanSearch } from "lucide-react";

/* ---------------- Types ---------------- */

type Decision = "ALLOW" | "BLOCK" | "HESITATE";
type AppMode = "chat" | "analyzer";

interface DecompositionStep {
  id: number;
  text: string;
  source_span?: string;
}

interface Decomposition {
  steps: DecompositionStep[];
  constraints: Record<string, any>;
  quality: {
    score: number;
  };
}

interface Claim {
  claim: string;
  source_step_id: number;
}

interface AnalysisResult {
  decision: Decision;
  riskScore: number;
  triggeredLayers: string[];
  semanticSimilarity: number;
  decomposition?: Decomposition;
  claims?: Claim[];
  ragResults?: RagEvidence[];
}

/* ---------------- App ---------------- */

export default function App() {
  const [mode, setMode] = useState<AppMode>("chat");

  // ---- Chat mode state ----
  const [lastPipelineId, setLastPipelineId] = useState<string | null>(null);
  const [lastDefenseMeta, setLastDefenseMeta] = useState<DefenseMeta | null>(null);

  // ---- Analyzer mode state ----
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [hasResult, setHasResult] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);
  const [showBreakdown, setShowBreakdown] = useState(false);
  const [result, setResult] = useState<AnalysisResult | null>(null);

  const [notification, setNotification] = useState({
    show: false,
    message: "",
    type: "info" as "info" | "success" | "error",
  });

  /* ---------------- Notifications ---------------- */

  const showNotification = (message: string, type: "info" | "success" | "error") => {
    setNotification({ show: true, message, type });
    setTimeout(() => setNotification({ show: false, message: "", type: "info" }), 3000);
  };

  /* ---------------- Analyzer handlers ---------------- */

  const handleAnalyze = async (prompt: string) => {
    setIsAnalyzing(true);
    setHasResult(false);
    setShowBreakdown(false);
    setCurrentStep(0);

    [0, 1, 2, 3].forEach((step, index) => {
      setTimeout(() => setCurrentStep(step), (index + 1) * 700);
    });

    try {
      const res = await fetch("http://127.0.0.1:5000/api/analyze", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ prompt }),
      });

      if (!res.ok) throw new Error("Backend error");

      const data = await res.json();

      const baseResult: AnalysisResult = {
        decision: data.status as Decision,
        riskScore: Math.round((data.decision_meta?.final_risk || 0) * 100),
        triggeredLayers: data.decision_meta?.triggered_layers || [],
        semanticSimilarity: Math.round((data.decision_meta?.semantic_similarity || 0) * 100),
      };

      if (data.status === "ALLOW") {
        setResult({
          ...baseResult,
          decomposition: data.decomposition,
          claims: data.claims ?? [],
          ragResults: data.rag_verification?.results ?? [],
        });
      } else {
        setResult(baseResult);
      }

      setHasResult(true);
      showNotification("Analysis complete", "success");
    } catch (err) {
      console.error(err);
      showNotification("Backend error (check console)", "error");
    } finally {
      setIsAnalyzing(false);
    }
  };

  const handleViewBreakdown = () => {
    if (!result || result.decision !== "ALLOW") {
      showNotification("This prompt was not allowed", "info");
      return;
    }
    if (!result.decomposition) {
      showNotification("No decomposition available", "info");
      return;
    }
    setShowBreakdown(true);
  };

  const handleAnalyzeAnother = () => {
    setHasResult(false);
    setResult(null);
    setCurrentStep(0);
    setShowBreakdown(false);
    showNotification("Ready for new analysis", "info");
  };

  const handleExport = () => {
    showNotification("Analysis exported successfully", "success");
  };

  /* ---------------- Chat mode handler ---------------- */

  const handlePipelineUpdate = (pipelineId: string, defenseMeta: DefenseMeta) => {
    setLastPipelineId(pipelineId);
    setLastDefenseMeta(defenseMeta);
  };

  /* ---------------- Mode Toggle Bar ---------------- */

  const ModeToggle = () => (
    <div className="flex items-center gap-1 bg-slate-800/60 border border-slate-700/40 rounded-xl p-1">
      <button
        onClick={() => setMode("chat")}
        className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all ${
          mode === "chat"
            ? "bg-gradient-to-r from-cyan-600 to-blue-600 text-white shadow-lg shadow-cyan-500/20"
            : "text-slate-400 hover:text-white hover:bg-slate-700/40"
        }`}
      >
        <MessageSquare className="w-4 h-4" />
        Chat
      </button>
      <button
        onClick={() => setMode("analyzer")}
        className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all ${
          mode === "analyzer"
            ? "bg-gradient-to-r from-cyan-600 to-blue-600 text-white shadow-lg shadow-cyan-500/20"
            : "text-slate-400 hover:text-white hover:bg-slate-700/40"
        }`}
      >
        <ScanSearch className="w-4 h-4" />
        Analyzer
      </button>
    </div>
  );

  /* ---------------- Chat Layout ---------------- */

  if (mode === "chat") {
    return (
      <div className="h-screen flex flex-col bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950 overflow-hidden">
        {/* Top bar */}
        <div className="flex-shrink-0 bg-slate-900/95 backdrop-blur-md border-b border-cyan-500/10 px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="relative">
              <div className="absolute inset-0 bg-cyan-500/20 blur-xl rounded-full" />
              <div className="relative w-8 h-8 bg-gradient-to-br from-cyan-500 to-blue-600 rounded-lg flex items-center justify-center shadow-lg shadow-cyan-500/30">
                <span className="text-white text-xs font-bold">A</span>
              </div>
            </div>
            <div>
              <h1 className="text-base font-bold text-white tracking-tight leading-none">AegisMind</h1>
              <p className="text-[10px] text-cyan-400/80 tracking-wide">When Defense Meets Reasoning</p>
            </div>
          </div>
          <ModeToggle />
        </div>

        <NotificationToast
          message={notification.message}
          type={notification.type}
          show={notification.show}
        />

        {/* Split layout */}
        <div className="flex flex-1 overflow-hidden">
          <ChatPanel onPipelineUpdate={handlePipelineUpdate} />
          <PipelineDashboard pipelineId={lastPipelineId} defenseMeta={lastDefenseMeta} />
        </div>

        {/* Background decoration */}
        <div className="fixed inset-0 -z-10 overflow-hidden pointer-events-none">
          <motion.div
            animate={{ scale: [1, 1.2, 1], opacity: [0.15, 0.25, 0.15] }}
            transition={{ duration: 8, repeat: Infinity }}
            className="absolute top-1/4 -left-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl"
          />
        </div>
      </div>
    );
  }

  /* ---------------- Analyzer Layout ---------------- */

  return (
    <div className="min-h-screen flex flex-col bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950">
      <div className="flex-shrink-0 bg-slate-900/95 backdrop-blur-md border-b border-cyan-500/10 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="relative">
              <div className="absolute inset-0 bg-cyan-500/20 blur-xl rounded-full" />
              <div className="relative w-10 h-10 bg-gradient-to-br from-cyan-500 to-blue-600 rounded-lg flex items-center justify-center shadow-lg shadow-cyan-500/30">
                <span className="text-white font-bold">A</span>
              </div>
            </div>
            <div>
              <h1 className="text-xl font-bold text-white tracking-tight">AegisMind</h1>
              <p className="text-xs text-cyan-400/80 tracking-wide">When Defense Meets Reasoning</p>
            </div>
          </div>
          <ModeToggle />
        </div>
      </div>

      <NotificationToast
        message={notification.message}
        type={notification.type}
        show={notification.show}
      />

      <main className="flex-1 w-full max-w-6xl mx-auto px-4 py-8 space-y-8">
        {!hasResult && <HeroSection onAnalyze={handleAnalyze} />}

        {(isAnalyzing || hasResult) && (
          <DefensePipeline
            isAnalyzing={isAnalyzing}
            currentStep={currentStep}
            decision={result?.decision}
          />
        )}

        {hasResult && result && (
          <DecisionOutput
            decision={result.decision}
            riskScore={result.riskScore}
            triggeredLayers={result.triggeredLayers}
            semanticSimilarity={result.semanticSimilarity}
          />
        )}

        {showBreakdown && result?.decomposition && (
          <DecompositionView
            decomposition={result.decomposition}
            claims={result.claims || []}
            ragResults={result.ragResults || []}
          />
        )}

        {hasResult && (
          <ActionControls
            onAnalyzeAnother={handleAnalyzeAnother}
            onViewBreakdown={handleViewBreakdown}
            onExport={handleExport}
          />
        )}
      </main>

      <Footer />

      <div className="fixed inset-0 -z-10 overflow-hidden pointer-events-none">
        <motion.div
          animate={{ scale: [1, 1.2, 1], opacity: [0.3, 0.5, 0.3] }}
          transition={{ duration: 8, repeat: Infinity }}
          className="absolute top-1/4 -left-1/4 w-96 h-96 bg-cyan-500/20 rounded-full blur-3xl"
        />
      </div>
    </div>
  );
}
