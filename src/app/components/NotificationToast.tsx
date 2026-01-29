import { AlertCircle, Info, CheckCircle2 } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';

interface NotificationToastProps {
  message: string;
  type?: 'info' | 'error' | 'success';
  show: boolean;
}

export function NotificationToast({ message, type = 'info', show }: NotificationToastProps) {
  const icons = {
    info: <Info className="w-5 h-5 text-cyan-400" />,
    error: <AlertCircle className="w-5 h-5 text-red-400" />,
    success: <CheckCircle2 className="w-5 h-5 text-emerald-400" />,
  };

  const styles = {
    info: 'bg-slate-800/95 border-cyan-500/30 text-cyan-100',
    error: 'bg-slate-800/95 border-red-500/30 text-red-100',
    success: 'bg-slate-800/95 border-emerald-500/30 text-emerald-100',
  };

  return (
    <AnimatePresence>
      {show && (
        <motion.div
          initial={{ opacity: 0, y: -20, scale: 0.95 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: -20, scale: 0.95 }}
          className="fixed top-20 right-4 z-50"
        >
          <div className={`flex items-center gap-3 px-4 py-3 rounded-xl border shadow-lg ${styles[type]}`}>
            {icons[type]}
            <p className="font-medium">{message}</p>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
