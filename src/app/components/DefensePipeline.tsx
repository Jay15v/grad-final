import { motion } from 'motion/react';
import {
  ShieldCheck,
  ScanSearch,
  AlertTriangle,
  GitBranch,
} from 'lucide-react';

type Decision = 'ALLOW' | 'BLOCK' | 'HESITATE';

interface DefensePipelineProps {
  isAnalyzing: boolean;
  currentStep: number;
  decision?: Decision;
}

const PIPELINE_STEPS = [
  {
    id: 0,
    title: 'User Input',
    description: 'Prompt submitted for analysis',
    icon: ScanSearch,
  },
  {
    id: 1,
    title: 'Safety Analysis',
    description: 'Multi-layer prompt risk detection',
    icon: ShieldCheck,
  },
  {
    id: 2,
    title: 'Decision',
    description: 'ALLOW / BLOCK / HESITATE',
    icon: AlertTriangle,
  },
  {
    id: 3,
    title: 'Decomposition',
    description: 'Structural breakdown into atomic steps',
    icon: GitBranch,
    gated: true, // 👈 only for ALLOW
  },
];

export function DefensePipeline({
  isAnalyzing,
  currentStep,
  decision,
}: DefensePipelineProps) {
  return (
    <motion.section
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6 }}
      className="w-full"
    >
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {PIPELINE_STEPS.map((step) => {
          const isActive = currentStep >= step.id;
          const isDecomposition = step.id === 3;
          const isAllowed = decision === 'ALLOW';

          const isEnabled =
            !step.gated || (step.gated && isAllowed);

          return (
            <motion.div
              key={step.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{
                opacity: isEnabled ? 1 : 0.4,
                y: 0,
              }}
              transition={{ delay: step.id * 0.15 }}
              className={`relative p-5 rounded-xl border backdrop-blur-sm
                ${
                  isActive && isEnabled
                    ? 'border-cyan-500/40 bg-slate-900/70'
                    : 'border-slate-700/40 bg-slate-900/40'
                }`}
            >
              <div className="flex items-center gap-3 mb-2">
                <step.icon
                  className={`w-6 h-6 ${
                    isActive && isEnabled
                      ? 'text-cyan-400'
                      : 'text-slate-500'
                  }`}
                />
                <h4 className="font-semibold text-white text-sm">
                  {step.title}
                </h4>
              </div>

              <p className="text-xs text-slate-400">
                {step.description}
              </p>

              {/* Gate message */}
              {isDecomposition && !isAllowed && !isAnalyzing && (
                <p className="mt-2 text-xs text-slate-500 italic">
                  Available only if ALLOW
                </p>
              )}
            </motion.div>
          );
        })}
      </div>
    </motion.section>
  );
}
