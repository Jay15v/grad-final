import { CheckCircle, XCircle, AlertTriangle, TrendingUp, Layers, Target } from 'lucide-react';
import { motion } from 'motion/react';

type Decision = 'ALLOW' | 'BLOCK' | 'HESITATE';

interface DecisionOutputProps {
  decision: Decision;
  riskScore: number;
  triggeredLayers: string[];
  semanticSimilarity: number;
}

export function DecisionOutput({
  decision,
  riskScore,
  triggeredLayers,
  semanticSimilarity,
}: DecisionOutputProps) {
  const decisionConfig = {
    ALLOW: {
      icon: CheckCircle,
      color: 'emerald',
      bgGradient: 'from-emerald-500/10 to-green-500/10',
      borderColor: 'border-emerald-500/30',
      textColor: 'text-emerald-400',
      shadowColor: 'shadow-emerald-500/20',
      glowColor: 'from-emerald-500/20',
    },
    BLOCK: {
      icon: XCircle,
      color: 'red',
      bgGradient: 'from-red-500/10 to-rose-500/10',
      borderColor: 'border-red-500/30',
      textColor: 'text-red-400',
      shadowColor: 'shadow-red-500/20',
      glowColor: 'from-red-500/20',
    },
    HESITATE: {
      icon: AlertTriangle,
      color: 'amber',
      bgGradient: 'from-amber-500/10 to-yellow-500/10',
      borderColor: 'border-amber-500/30',
      textColor: 'text-amber-400',
      shadowColor: 'shadow-amber-500/20',
      glowColor: 'from-amber-500/20',
    },
  };

  const config = decisionConfig[decision];
  const Icon = config.icon;

  return (
    <motion.section
      initial={{ y: 30, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.6, delay: 0.6 }}
      className="w-full"
    >
      <div className="mb-6">
        <h3 className="text-2xl font-bold text-white mb-2">AegisMind Decision</h3>
        <p className="text-slate-400">Comprehensive analysis results and risk assessment</p>
      </div>

      <div className={`bg-gradient-to-br ${config.bgGradient} backdrop-blur-sm border ${config.borderColor} rounded-2xl shadow-2xl ${config.shadowColor} p-8 md:p-10 relative overflow-hidden`}>
        {/* Animated background glow */}
        <motion.div
          className={`absolute inset-0 bg-gradient-to-r ${config.glowColor} via-transparent to-transparent opacity-30 -z-10`}
          animate={{ x: ['-100%', '100%'] }}
          transition={{ duration: 3, repeat: Infinity, ease: 'linear' }}
        />

        {/* Main Decision */}
        <div className="text-center mb-8">
          <motion.div
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ type: 'spring', stiffness: 200, damping: 15, delay: 0.7 }}
            className="inline-flex items-center justify-center mb-4"
          >
            <div className="relative">
              <div className={`absolute inset-0 bg-gradient-to-br ${config.glowColor} via-transparent blur-2xl`} />
              <Icon className={`w-20 h-20 ${config.textColor} relative z-10`} strokeWidth={2} />
            </div>
          </motion.div>
          
          <motion.h2
            initial={{ y: 20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ delay: 0.8 }}
            className={`text-5xl md:text-6xl font-bold ${config.textColor} mb-2 tracking-tight`}
          >
            {decision}
          </motion.h2>
          
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.9 }}
            className="text-slate-400"
          >
            {decision === 'ALLOW' && 'Prompt is safe and approved for processing'}
            {decision === 'BLOCK' && 'Prompt contains potential security risks'}
            {decision === 'HESITATE' && 'Prompt requires additional review'}
          </motion.p>
        </div>

        {/* Metrics Grid */}
        <motion.div
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 1 }}
          className="grid md:grid-cols-3 gap-4"
        >
          {/* Risk Score */}
          <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700/50 rounded-xl p-5">
            <div className="flex items-center gap-2 mb-3">
              <div className="w-8 h-8 bg-purple-500/20 rounded-lg flex items-center justify-center">
                <TrendingUp className="w-5 h-5 text-purple-400" />
              </div>
              <h4 className="font-semibold text-white text-sm">Risk Score</h4>
            </div>
            <div className="flex items-end gap-2">
              <span className="text-3xl font-bold text-white">{riskScore}</span>
              <span className="text-slate-400 text-sm mb-1">/ 100</span>
            </div>
            <div className="mt-3 h-2 bg-slate-700/50 rounded-full overflow-hidden">
              <motion.div
                initial={{ width: 0 }}
                animate={{ width: `${riskScore}%` }}
                transition={{ duration: 1, delay: 1.2 }}
                className={`h-full rounded-full ${
                  riskScore < 30
                    ? 'bg-gradient-to-r from-emerald-500 to-green-500'
                    : riskScore < 70
                    ? 'bg-gradient-to-r from-amber-500 to-yellow-500'
                    : 'bg-gradient-to-r from-red-500 to-rose-500'
                }`}
              />
            </div>
          </div>

          {/* Triggered Layers */}
          <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700/50 rounded-xl p-5">
            <div className="flex items-center gap-2 mb-3">
              <div className="w-8 h-8 bg-cyan-500/20 rounded-lg flex items-center justify-center">
                <Layers className="w-5 h-5 text-cyan-400" />
              </div>
              <h4 className="font-semibold text-white text-sm">Triggered Layers</h4>
            </div>
            <div className="flex items-end gap-2 mb-2">
              <span className="text-3xl font-bold text-white">{triggeredLayers.length}</span>
              <span className="text-slate-400 text-sm mb-1">/ 4 layers</span>
            </div>
            <div className="flex flex-wrap gap-1 mt-2">
              {triggeredLayers.map((layer, index) => (
                <span
                  key={index}
                  className="text-xs px-2 py-1 bg-cyan-500/20 text-cyan-400 rounded"
                >
                  {layer}
                </span>
              ))}
            </div>
          </div>

          {/* Semantic Similarity */}
          <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700/50 rounded-xl p-5">
            <div className="flex items-center gap-2 mb-3">
              <div className="w-8 h-8 bg-blue-500/20 rounded-lg flex items-center justify-center">
                <Target className="w-5 h-5 text-blue-400" />
              </div>
              <h4 className="font-semibold text-white text-sm">Semantic Match</h4>
            </div>
            <div className="flex items-end gap-2">
              <span className="text-3xl font-bold text-white">{semanticSimilarity}</span>
              <span className="text-slate-400 text-sm mb-1">%</span>
            </div>
            <p className="text-xs text-slate-500 mt-2">
              Sentence-BERT contextual similarity to known threat patterns
            </p>
          </div>
        </motion.div>
      </div>
    </motion.section>
  );
}