import { Sparkles, Shield } from 'lucide-react';
import { motion } from 'motion/react';
import { useState } from 'react';

interface HeroSectionProps {
  onAnalyze: (prompt: string) => void;
}

export function HeroSection({ onAnalyze }: HeroSectionProps) {
  const [prompt, setPrompt] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (prompt.trim()) {
      onAnalyze(prompt);
    }
  };

  return (
    <motion.section
      initial={{ y: 30, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.6, delay: 0.2 }}
      className="w-full"
    >
      <div className="bg-gradient-to-br from-slate-800/50 to-slate-900/50 backdrop-blur-sm rounded-2xl border border-cyan-500/20 shadow-2xl shadow-cyan-500/10 p-8 md:p-10">
        {/* Heading */}
        <div className="text-center mb-8">
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ delay: 0.3 }}
            className="inline-flex items-center gap-2 mb-4"
          >
            <Sparkles className="w-6 h-6 text-cyan-400" />
            <h2 className="text-3xl md:text-4xl font-bold text-white">
              Submit a Prompt for Analysis
            </h2>
          </motion.div>
          <p className="text-slate-400 max-w-2xl mx-auto leading-relaxed">
            AegisMind evaluates intent, safety, and semantic risk using layered AI defense.
          </p>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="relative">
            <textarea
              value={prompt}
              onChange={(e) => setPrompt(e.target.value)}
              placeholder="Enter your prompt here..."
              rows={6}
              className="w-full px-5 py-4 bg-slate-900/80 border-2 border-slate-700/50 rounded-xl text-white placeholder-slate-500 focus:border-cyan-500/50 focus:ring-4 focus:ring-cyan-500/10 focus:outline-none transition-all duration-300 resize-none"
            />
            <div className="absolute inset-0 -z-10 bg-gradient-to-r from-cyan-500/0 via-cyan-500/5 to-blue-500/0 rounded-xl blur-xl opacity-0 group-focus-within:opacity-100 transition-opacity duration-500" />
          </div>

          <motion.button
            type="submit"
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="w-full py-4 px-6 bg-gradient-to-r from-cyan-600 to-blue-600 hover:from-cyan-500 hover:to-blue-500 text-white font-semibold rounded-xl shadow-lg shadow-cyan-500/30 hover:shadow-cyan-500/50 transition-all duration-300 flex items-center justify-center gap-2 group"
          >
            <Shield className="w-5 h-5 group-hover:rotate-12 transition-transform" />
            Analyze Prompt
          </motion.button>
        </form>
      </div>
    </motion.section>
  );
}
