import { RotateCcw, FileText, Download } from 'lucide-react';
import { motion } from 'motion/react';

interface ActionControlsProps {
  onAnalyzeAnother: () => void;
  onViewBreakdown: () => void;
  onExport: () => void;
}

export function ActionControls({
  onAnalyzeAnother,
  onViewBreakdown,
  onExport,
}: ActionControlsProps) {
  return (
    <motion.section
      initial={{ y: 20, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.6, delay: 0.8 }}
      className="w-full"
    >
      <div className="flex flex-col sm:flex-row gap-4 justify-center">
        {/* Primary Button */}
        <motion.button
          onClick={onAnalyzeAnother}
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className="px-6 py-3 bg-gradient-to-r from-cyan-600 to-blue-600 hover:from-cyan-500 hover:to-blue-500 text-white font-semibold rounded-xl shadow-lg shadow-cyan-500/30 hover:shadow-cyan-500/50 transition-all duration-300 flex items-center justify-center gap-2 group"
        >
          <RotateCcw className="w-5 h-5 group-hover:rotate-180 transition-transform duration-500" />
          Analyze Another Prompt
        </motion.button>

        {/* Secondary Button */}
        <motion.button
          onClick={onViewBreakdown}
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className="px-6 py-3 bg-slate-800/50 hover:bg-slate-700/50 border border-slate-700/50 hover:border-cyan-500/30 text-slate-300 hover:text-white font-semibold rounded-xl transition-all duration-300 flex items-center justify-center gap-2 group"
        >
          <FileText className="w-5 h-5 text-cyan-400 group-hover:scale-110 transition-transform" />
          View Defense Breakdown
        </motion.button>

        {/* Tertiary Button */}
        <motion.button
          onClick={onExport}
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className="px-6 py-3 bg-slate-800/30 hover:bg-slate-800/50 border border-slate-700/30 hover:border-slate-600/50 text-slate-400 hover:text-slate-300 font-semibold rounded-xl transition-all duration-300 flex items-center justify-center gap-2 group"
        >
          <Download className="w-5 h-5 group-hover:translate-y-0.5 transition-transform" />
          Export Analysis
        </motion.button>
      </div>
    </motion.section>
  );
}
