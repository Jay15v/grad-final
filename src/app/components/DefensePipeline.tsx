import { Shield, Database, Brain, Activity, ChevronRight } from 'lucide-react';
import { motion } from 'motion/react';

interface DefensePipelineProps {
  isAnalyzing: boolean;
  currentStep?: number;
}

export function DefensePipeline({ isAnalyzing, currentStep = 0 }: DefensePipelineProps) {
  const steps = [
    {
      icon: Shield,
      title: 'Rule-Based Defense',
      description: 'First-line pattern matching and keyword filtering',
    },
    {
      icon: Database,
      title: 'Pattern Knowledge Base',
      description: 'Historical threat patterns and known attack vectors',
    },
    {
      icon: Brain,
      title: 'Semantic Reasoning',
      description: 'Sentence-BERT deep contextual understanding',
    },
    {
      icon: Activity,
      title: 'Risk Fusion & Calibration',
      description: 'Multi-layer decision aggregation and confidence scoring',
    },
  ];

  return (
    <motion.section
      initial={{ y: 30, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.6, delay: 0.4 }}
      className="w-full"
    >
      <div className="mb-6">
        <h3 className="text-2xl font-bold text-white mb-2">AI Defense Pipeline</h3>
        <p className="text-slate-400">Multi-layered analysis ensures comprehensive threat detection</p>
      </div>

      {/* Desktop: Horizontal */}
      <div className="hidden md:grid md:grid-cols-4 gap-4">
        {steps.map((step, index) => {
          const Icon = step.icon;
          const isActive = isAnalyzing && index <= currentStep;
          const isCompleted = isAnalyzing && index < currentStep;

          return (
            <div key={index} className="flex items-center gap-2">
              <motion.div
                initial={{ scale: 0.9, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                transition={{ delay: 0.5 + index * 0.1 }}
                className={`flex-1 relative group ${
                  isActive ? 'ring-2 ring-cyan-500/50' : ''
                }`}
              >
                <div className={`bg-slate-800/50 backdrop-blur-sm border rounded-xl p-5 transition-all duration-300 ${
                  isActive
                    ? 'border-cyan-500/50 shadow-lg shadow-cyan-500/20'
                    : 'border-slate-700/50 hover:border-slate-600/50'
                }`}>
                  <div className="flex items-center gap-3 mb-3">
                    <div className={`w-10 h-10 rounded-lg flex items-center justify-center transition-all ${
                      isCompleted
                        ? 'bg-emerald-500/20 text-emerald-400'
                        : isActive
                        ? 'bg-cyan-500/20 text-cyan-400'
                        : 'bg-slate-700/50 text-slate-400'
                    }`}>
                      <Icon className="w-5 h-5" />
                    </div>
                    <div className={`text-xs font-semibold px-2 py-1 rounded ${
                      isActive ? 'bg-cyan-500/20 text-cyan-400' : 'bg-slate-700/50 text-slate-500'
                    }`}>
                      Step {index + 1}
                    </div>
                  </div>
                  <h4 className="font-semibold text-white text-sm mb-1">
                    {step.title}
                  </h4>
                  <p className="text-xs text-slate-400 leading-relaxed">
                    {step.description}
                  </p>
                  
                  {isActive && (
                    <motion.div
                      className="absolute inset-0 bg-cyan-500/5 rounded-xl -z-10"
                      animate={{ opacity: [0.3, 0.6, 0.3] }}
                      transition={{ duration: 2, repeat: Infinity }}
                    />
                  )}
                </div>
              </motion.div>

              {index < steps.length - 1 && (
                <ChevronRight className={`w-5 h-5 flex-shrink-0 ${
                  isCompleted ? 'text-cyan-400' : 'text-slate-600'
                }`} />
              )}
            </div>
          );
        })}
      </div>

      {/* Mobile: Vertical */}
      <div className="md:hidden space-y-3">
        {steps.map((step, index) => {
          const Icon = step.icon;
          const isActive = isAnalyzing && index <= currentStep;
          const isCompleted = isAnalyzing && index < currentStep;

          return (
            <motion.div
              key={index}
              initial={{ x: -20, opacity: 0 }}
              animate={{ x: 0, opacity: 1 }}
              transition={{ delay: 0.5 + index * 0.1 }}
              className={`bg-slate-800/50 backdrop-blur-sm border rounded-xl p-4 transition-all ${
                isActive
                  ? 'border-cyan-500/50 shadow-lg shadow-cyan-500/20'
                  : 'border-slate-700/50'
              }`}
            >
              <div className="flex items-start gap-3">
                <div className={`w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0 ${
                  isCompleted
                    ? 'bg-emerald-500/20 text-emerald-400'
                    : isActive
                    ? 'bg-cyan-500/20 text-cyan-400'
                    : 'bg-slate-700/50 text-slate-400'
                }`}>
                  <Icon className="w-5 h-5" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <h4 className="font-semibold text-white text-sm">
                      {step.title}
                    </h4>
                    <div className={`text-xs font-semibold px-2 py-0.5 rounded ${
                      isActive ? 'bg-cyan-500/20 text-cyan-400' : 'bg-slate-700/50 text-slate-500'
                    }`}>
                      {index + 1}
                    </div>
                  </div>
                  <p className="text-xs text-slate-400">
                    {step.description}
                  </p>
                </div>
              </div>
            </motion.div>
          );
        })}
      </div>
    </motion.section>
  );
}
