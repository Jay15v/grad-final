import { useState } from 'react';
import { Header } from './components/Header';
import { Footer } from './components/Footer';
import { HeroSection } from './components/HeroSection';
import { DefensePipeline } from './components/DefensePipeline';
import { DecisionOutput } from './components/DecisionOutput';
import { ActionControls } from './components/ActionControls';
import { NotificationToast } from './components/NotificationToast';
import { motion } from 'motion/react';

type Decision = 'ALLOW' | 'BLOCK' | 'HESITATE';

export default function App() {
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [hasResult, setHasResult] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);
  const [notification, setNotification] = useState({
    show: false,
    message: '',
    type: 'info' as 'info' | 'success' | 'error',
  });

  const [result, setResult] = useState<{
    decision: Decision;
    riskScore: number;
    triggeredLayers: string[];
    semanticSimilarity: number;
  } | null>(null);

  const showNotification = (
    message: string,
    type: 'info' | 'success' | 'error'
  ) => {
    setNotification({ show: true, message, type });
    setTimeout(() => {
      setNotification({ show: false, message: '', type: 'info' });
    }, 3000);
  };

  const handleAnalyze = async (prompt: string) => {
    setIsAnalyzing(true);
    setHasResult(false);
    setCurrentStep(0);

    // Animate pipeline steps
    const steps = [0, 1, 2, 3];
    steps.forEach((step, index) => {
      setTimeout(() => setCurrentStep(step), (index + 1) * 700);
    });

    try {
      const res = await fetch('http://127.0.0.1:5000/api/analyze', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ prompt }),
      });

      if (!res.ok) {
        throw new Error('Backend error');
      }

      const data = await res.json();

     setResult({
  decision: data.decision,
  riskScore: Math.round(data.final_risk * 100),
  triggeredLayers: data.triggered_layers,
  semanticSimilarity: Math.round(data.semantic_similarity * 100),
});


      setHasResult(true);
      showNotification('Analysis complete (real model)', 'success');
    } catch (err) {
      console.error(err);
      showNotification('Backend connection failed', 'error');
    } finally {
      setIsAnalyzing(false);
    }
  };

  const handleAnalyzeAnother = () => {
    setHasResult(false);
    setResult(null);
    setCurrentStep(0);
    showNotification('Ready for new analysis', 'info');
  };

  const handleViewBreakdown = () => {
    showNotification('Detailed breakdown coming soon', 'info');
  };

  const handleExport = () => {
    showNotification('Analysis exported successfully', 'success');
  };

  return (
    <div className="min-h-screen flex flex-col bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950">
      <Header />

      <NotificationToast
        message={notification.message}
        type={notification.type}
        show={notification.show}
      />

      <main className="flex-1 w-full max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12 space-y-8">
        {!hasResult && <HeroSection onAnalyze={handleAnalyze} />}

        {(isAnalyzing || hasResult) && (
          <DefensePipeline
            isAnalyzing={isAnalyzing}
            currentStep={currentStep}
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

        {hasResult && (
          <ActionControls
            onAnalyzeAnother={handleAnalyzeAnother}
            onViewBreakdown={handleViewBreakdown}
            onExport={handleExport}
          />
        )}
      </main>

      <Footer />

      {/* Decorative Elements */}
      <div className="fixed inset-0 -z-10 overflow-hidden pointer-events-none">
        <motion.div
          animate={{ scale: [1, 1.2, 1], opacity: [0.3, 0.5, 0.3] }}
          transition={{ duration: 8, repeat: Infinity }}
          className="absolute top-1/4 -left-1/4 w-96 h-96 bg-cyan-500/20 rounded-full blur-3xl"
        />
        <motion.div
          animate={{ scale: [1.2, 1, 1.2], opacity: [0.2, 0.4, 0.2] }}
          transition={{ duration: 10, repeat: Infinity }}
          className="absolute bottom-1/4 -right-1/4 w-96 h-96 bg-blue-600/20 rounded-full blur-3xl"
        />
        <motion.div
          animate={{ scale: [1, 1.3, 1], opacity: [0.2, 0.3, 0.2] }}
          transition={{ duration: 12, repeat: Infinity }}
          className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-purple-600/10 rounded-full blur-3xl"
        />
      </div>
    </div>
  );
}