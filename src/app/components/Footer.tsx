import { motion } from 'motion/react';

export function Footer() {
  return (
    <motion.footer
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ delay: 1 }}
      className="w-full border-t border-slate-800/50 bg-slate-900/95 backdrop-blur-sm mt-auto"
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="text-center space-y-1">
          <p className="text-slate-400 font-medium">
            <span className="text-cyan-400">AegisMind</span> – Graduation Project
          </p>
          <p className="text-sm text-slate-500">
            AI Safety & Prompt Defense System
          </p>
        </div>
      </div>
    </motion.footer>
  );
}
