import { useState } from "react";
import { Header } from "./components/Header";
import { Footer } from "./components/Footer";
import { HeroSection } from "./components/HeroSection";
import { DefensePipeline } from "./components/DefensePipeline";
import { DecisionOutput } from "./components/DecisionOutput";
import { ActionControls } from "./components/ActionControls";
import { NotificationToast } from "./components/NotificationToast";
import { DecompositionView } from "./components/DecompositionView";
import { motion } from "motion/react";
import { RagEvidence } from "./types/rag";



/* ---------------- Types ---------------- */

type Decision = "ALLOW" | "BLOCK" | "HESITATE";

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
  ragVerification?: {
  results: RagEvidence[];
  rag_eval: {
    total_steps: number;
    hits: number;
    misses: number;
    hit_rate: number;
  };
};

}

/* ---------------- App ---------------- */

export default function App() {
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

  const showNotification = (
    message: string,
    type: "info" | "success" | "error"
  ) => {
    setNotification({ show: true, message, type });
    setTimeout(
      () =>
        setNotification({
          show: false,
          message: "",
          type: "info",
        }),
      3000
    );
  };

  /* ---------------- Analyze ---------------- */

  const handleAnalyze = async (prompt: string) => {
    setIsAnalyzing(true);
    setHasResult(false);
    setShowBreakdown(false);
    setCurrentStep(0);

    [0, 1, 2, 3].forEach((step, index) => {
      setTimeout(() => setCurrentStep(step), (index + 1) * 700);
    });

    try {
      const res = await fetch("http://localhost:5000/api/analyze", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ prompt }),
      });

      if (!res.ok) throw new Error("Backend error");

      const data = await res.json();

      const baseResult: AnalysisResult = {
        decision: data.status as Decision,
        riskScore: Math.round(
          (data.decision_meta?.final_risk || 0) * 100
        ),
        triggeredLayers: data.decision_meta?.triggered_layers || [],
        semanticSimilarity: Math.round(
          (data.decision_meta?.semantic_similarity || 0) * 100
        ),
      };

      if (data.status === "ALLOW") {
        setResult({
          ...baseResult,
          decomposition: data.decomposition,
          claims: data.claims ?? [],
          ragVerification: data.rag_verification ?? { results: [], rag_eval: { total_steps: 0, hits: 0, misses: 0, hit_rate: 0 } },
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

  /* ---------------- View Breakdown ---------------- */

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

  /* ---------------- Reset ---------------- */

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

  /* ---------------- Render ---------------- */

  return (
    <div className="min-h-screen flex flex-col bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950">
      <Header />

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
           ragResults={result.ragVerification?.results || []}
           ragEval={result.ragVerification?.rag_eval}
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

      {/* Decorative background */}
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
