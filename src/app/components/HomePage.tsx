import { useState } from 'react';
import { HeroSection } from '@/app/components/HeroSection';
import { DefensePipeline } from '@/app/components/DefensePipeline';
import { DecisionOutput } from '@/app/components/DecisionOutput';
import { ActionControls } from '@/app/components/ActionControls';
import { NotificationToast } from '@/app/components/NotificationToast';
import { motion } from 'motion/react';
import { useAuth } from '@/app/context/AuthContext';

type Decision = 'ALLOW' | 'BLOCK' | 'HESITATE';

export function HomePage() {
  const { updateStats } = useAuth();
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [hasResult, setHasResult] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);
  const [notification, setNotification] = useState({ show: false, message: '', type: 'info' as const });
  
  // Mock result data
  const [result, setResult] = useState<{
    decision: Decision;
    riskScore: number;
    triggeredLayers: string[];
    semanticSimilarity: number;
  } | null>(null);

  const handleAnalyze = (prompt: string) => {
    setIsAnalyzing(true);
    setHasResult(false);
    setCurrentStep(0);

    // Simulate step-by-step analysis
    const steps = [0, 1, 2, 3];
    steps.forEach((step, index) => {
      setTimeout(() => {
        setCurrentStep(step);
      }, (index + 1) * 800);
    });

    // Simulate analysis completion
    setTimeout(async () => {
      setIsAnalyzing(false);
      setHasResult(true);
      
      // Generate mock result based on prompt content
      const isSafe = !prompt.toLowerCase().includes('hack') && 
                     !prompt.toLowerCase().includes('attack') &&
                     !prompt.toLowerCase().includes('exploit');
      
      const isAmbiguous = prompt.toLowerCase().includes('test') ||
                          prompt.toLowerCase().includes('try');

      let decision: Decision;
      let riskScore: number;
      let layers: string[];
      
      if (isSafe && !isAmbiguous) {
        decision = 'ALLOW';
        riskScore = Math.floor(Math.random() * 30);
        layers = ['Rule-Based'];
      } else if (!isSafe) {
        decision = 'BLOCK';
        riskScore = Math.floor(Math.random() * 30) + 70;
        layers = ['Rule-Based', 'Pattern KB', 'Semantic', 'Risk Fusion'];
      } else {
        decision = 'HESITATE';
        riskScore = Math.floor(Math.random() * 40) + 30;
        layers = ['Rule-Based', 'Pattern KB', 'Semantic'];
      }

      setResult({
        decision,
        riskScore,
        triggeredLayers: layers,
        semanticSimilarity: Math.floor(Math.random() * 40) + 60,
      });

      // Update user stats in database
      await updateStats(decision);

      showNotification('Analysis complete! View results below.', 'success');
    }, 4000);
  };

  const handleAnalyzeAnother = () => {
    setHasResult(false);
    setResult(null);
    setCurrentStep(0);
    showNotification('Ready for new analysis', 'info');
  };

  const handleViewBreakdown = () => {
    showNotification('Detailed breakdown feature coming soon', 'info');
  };

  const handleExport = () => {
    showNotification('Analysis exported successfully', 'success');
  };

  const showNotification = (message: string, type: 'info' | 'success' | 'error') => {
    setNotification({ show: true, message, type });
    setTimeout(() => {
      setNotification({ show: false, message: '', type: 'info' });
    }, 3000);
  };

  return (
    <>
      <NotificationToast
        message={notification.message}
        type={notification.type}
        show={notification.show}
      />

      <main className="flex-1 w-full max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12 space-y-8">
        {/* Hero Section - Always visible */}
        {!hasResult && <HeroSection onAnalyze={handleAnalyze} />}

        {/* Defense Pipeline - Show during and after analysis */}
        {(isAnalyzing || hasResult) && (
          <DefensePipeline isAnalyzing={isAnalyzing} currentStep={currentStep} />
        )}

        {/* Decision Output - Show after analysis */}
        {hasResult && result && (
          <DecisionOutput
            decision={result.decision}
            riskScore={result.riskScore}
            triggeredLayers={result.triggeredLayers}
            semanticSimilarity={result.semanticSimilarity}
          />
        )}

        {/* Action Controls - Show after analysis */}
        {hasResult && (
          <ActionControls
            onAnalyzeAnother={handleAnalyzeAnother}
            onViewBreakdown={handleViewBreakdown}
            onExport={handleExport}
          />
        )}
      </main>

      {/* Decorative Elements */}
      <div className="fixed inset-0 -z-10 overflow-hidden pointer-events-none">
        {/* Animated gradient orbs */}
        <motion.div
          animate={{
            scale: [1, 1.2, 1],
            opacity: [0.3, 0.5, 0.3],
          }}
          transition={{
            duration: 8,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
          className="absolute top-1/4 -left-1/4 w-96 h-96 bg-cyan-500/20 rounded-full blur-3xl"
        />
        <motion.div
          animate={{
            scale: [1.2, 1, 1.2],
            opacity: [0.2, 0.4, 0.2],
          }}
          transition={{
            duration: 10,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
          className="absolute bottom-1/4 -right-1/4 w-96 h-96 bg-blue-600/20 rounded-full blur-3xl"
        />
        <motion.div
          animate={{
            scale: [1, 1.3, 1],
            opacity: [0.2, 0.3, 0.2],
          }}
          transition={{
            duration: 12,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
          className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-purple-600/10 rounded-full blur-3xl"
        />
      </div>

      {/* Grid pattern overlay */}
      <div className="fixed inset-0 -z-10 opacity-[0.02] pointer-events-none">
        <div
          className="w-full h-full"
          style={{
            backgroundImage: `
              linear-gradient(to right, cyan 1px, transparent 1px),
              linear-gradient(to bottom, cyan 1px, transparent 1px)
            `,
            backgroundSize: '40px 40px',
          }}
        />
      </div>
    </>
  );
}