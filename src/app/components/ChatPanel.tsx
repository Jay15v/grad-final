import { useState, useRef, useEffect } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Send, ShieldOff, Shield, AlertTriangle, Bot, User, Loader2 } from "lucide-react";

/* ---------- Types ---------- */

export interface DefenseMeta {
  decision: string;
  bert_risk: number;
  semantic_domain: string;
  semantic_similarity: number;
  final_risk: number;
}

interface Message {
  id: string;
  role: "user" | "assistant" | "blocked";
  content: string;
  decision?: string;
  defenseMeta?: DefenseMeta;
  pipelineId?: string;
}

interface ChatPanelProps {
  onPipelineUpdate: (pipelineId: string, defenseMeta: DefenseMeta) => void;
}

/* ---------- Sub-components ---------- */

function DefenseBadge({ meta }: { meta: DefenseMeta }) {
  const risk = Math.round(meta.final_risk * 100);
  const isBlock = meta.decision === "BLOCK";
  const isHesitate = meta.decision === "HESITATE";

  return (
    <div className={`flex items-center gap-2 text-[10px] mt-1 px-2 py-1 rounded-md w-fit
      ${isBlock ? "bg-red-900/30 text-red-400" : isHesitate ? "bg-yellow-900/30 text-yellow-400" : "bg-cyan-900/20 text-cyan-400"}`}>
      <Shield className="w-3 h-3" />
      <span>Risk {risk}%</span>
      <span className="opacity-60">·</span>
      <span className="capitalize">{(meta.semantic_domain ?? "").replace(/_/g, " ")}</span>
    </div>
  );
}

function MessageBubble({ msg }: { msg: Message }) {
  if (msg.role === "user") {
    return (
      <motion.div
        initial={{ opacity: 0, x: 20 }}
        animate={{ opacity: 1, x: 0 }}
        className="flex justify-end"
      >
        <div className="max-w-[75%]">
          <div className="flex items-center gap-2 justify-end mb-1">
            <span className="text-xs text-slate-500">You</span>
            <User className="w-3.5 h-3.5 text-slate-500" />
          </div>
          <div className="bg-gradient-to-br from-cyan-600 to-blue-600 text-white px-4 py-2.5 rounded-2xl rounded-tr-sm text-sm leading-relaxed shadow-lg shadow-cyan-500/20">
            {msg.content}
          </div>
        </div>
      </motion.div>
    );
  }

  if (msg.role === "blocked") {
    return (
      <motion.div
        initial={{ opacity: 0, x: -20 }}
        animate={{ opacity: 1, x: 0 }}
        className="flex justify-start"
      >
        <div className="max-w-[75%]">
          <div className="flex items-center gap-2 mb-1">
            <ShieldOff className="w-3.5 h-3.5 text-red-400" />
            <span className="text-xs text-red-400 font-medium">Blocked</span>
          </div>
          <div className="bg-red-900/30 border border-red-500/30 text-red-300 px-4 py-2.5 rounded-2xl rounded-tl-sm text-sm leading-relaxed">
            This message was blocked by the defense pipeline.
            {msg.defenseMeta && (
              <span className="block mt-1 text-red-400/70 text-xs">
                Risk {Math.round(msg.defenseMeta.final_risk * 100)}% · {(msg.defenseMeta.semantic_domain ?? "").replace(/_/g, " ")}
              </span>
            )}
          </div>
        </div>
      </motion.div>
    );
  }

  if (msg.role === "assistant" && msg.content === "__loading__") {
    return (
      <motion.div
        initial={{ opacity: 0, x: -20 }}
        animate={{ opacity: 1, x: 0 }}
        className="flex justify-start"
      >
        <div className="max-w-[75%]">
          <div className="flex items-center gap-2 mb-1">
            <Bot className="w-3.5 h-3.5 text-cyan-400" />
            <span className="text-xs text-slate-500">AegisMind</span>
          </div>
          <div className="bg-slate-800/70 border border-slate-700/50 px-4 py-3 rounded-2xl rounded-tl-sm flex items-center gap-2">
            <Loader2 className="w-4 h-4 text-cyan-400 animate-spin" />
            <span className="text-slate-400 text-sm">Thinking...</span>
          </div>
        </div>
      </motion.div>
    );
  }

  return (
    <motion.div
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      className="flex justify-start"
    >
      <div className="max-w-[75%]">
        <div className="flex items-center gap-2 mb-1">
          <Bot className="w-3.5 h-3.5 text-cyan-400" />
          <span className="text-xs text-slate-500">AegisMind</span>
          {msg.decision === "ALLOW" && (
            <span className="text-[10px] text-green-400 bg-green-900/20 px-1.5 py-0.5 rounded-full">ALLOWED</span>
          )}
          {msg.decision === "HESITATE" && (
            <span className="text-[10px] text-yellow-400 bg-yellow-900/20 px-1.5 py-0.5 rounded-full">HESITATE</span>
          )}
        </div>
        <div className="bg-slate-800/70 border border-slate-700/50 text-slate-100 px-4 py-2.5 rounded-2xl rounded-tl-sm text-sm leading-relaxed">
          {msg.content}
        </div>
        {msg.defenseMeta && <DefenseBadge meta={msg.defenseMeta} />}
      </div>
    </motion.div>
  );
}

/* ---------- Main Component ---------- */

export function ChatPanel({ onPipelineUpdate }: ChatPanelProps) {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: "welcome",
      role: "assistant",
      content: "Hello! I'm AegisMind. Every message you send is checked by the defense pipeline before I respond. Ask me anything.",
    },
  ]);
  const [input, setInput] = useState("");
  const [isSending, setIsSending] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const buildHistory = () =>
    messages
      .filter((m) => m.role === "user" || (m.role === "assistant" && m.content !== "__loading__"))
      .slice(-10)
      .map((m) => ({ role: m.role === "assistant" ? "assistant" : "user", content: m.content }));

  const handleSend = async () => {
    const text = input.trim();
    if (!text || isSending) return;

    setInput("");
    setIsSending(true);

    const userMsgId = crypto.randomUUID();
    const loadingMsgId = crypto.randomUUID();

    setMessages((prev) => [
      ...prev,
      { id: userMsgId, role: "user", content: text },
      { id: loadingMsgId, role: "assistant", content: "__loading__" },
    ]);

    try {
      const res = await fetch("http://127.0.0.1:5000/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: text, history: buildHistory() }),
      });

      if (!res.ok) throw new Error("Backend error");

      const data = await res.json();

      if (data.decision === "BLOCK") {
        setMessages((prev) =>
          prev
            .filter((m) => m.id !== loadingMsgId)
            .concat({
              id: crypto.randomUUID(),
              role: "blocked",
              content: "",
              decision: "BLOCK",
              defenseMeta: data.defense_meta,
            })
        );
        if (data.defense_meta) {
          onPipelineUpdate("blocked-" + userMsgId, data.defense_meta);
        }
      } else {
        setMessages((prev) =>
          prev
            .filter((m) => m.id !== loadingMsgId)
            .concat({
              id: crypto.randomUUID(),
              role: "assistant",
              content: data.reply || "(no response)",
              decision: data.decision,
              defenseMeta: data.defense_meta,
              pipelineId: data.pipeline_id,
            })
        );
        if (data.pipeline_id && data.defense_meta) {
          onPipelineUpdate(data.pipeline_id, data.defense_meta);
        }
      }
    } catch (err) {
      setMessages((prev) =>
        prev
          .filter((m) => m.id !== loadingMsgId)
          .concat({
            id: crypto.randomUUID(),
            role: "assistant",
            content: "Error: Could not reach the backend. Make sure it's running on port 5000.",
          })
      );
    } finally {
      setIsSending(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className="flex flex-col w-[45%] h-full border-r border-slate-700/40">
      {/* Header */}
      <div className="px-4 py-3 border-b border-slate-700/40 flex items-center gap-2 flex-shrink-0">
        <div className="w-2 h-2 rounded-full bg-green-400 shadow-sm shadow-green-400" />
        <span className="text-white font-semibold text-sm">Chat</span>
        <span className="text-slate-500 text-xs ml-auto">phi3 · defense-gated</span>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-4">
        <AnimatePresence initial={false}>
          {messages.map((msg) => (
            <MessageBubble key={msg.id} msg={msg} />
          ))}
        </AnimatePresence>
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className="px-4 py-3 border-t border-slate-700/40 flex-shrink-0">
        <div className="flex gap-2 items-end">
          <textarea
            ref={textareaRef}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Type a message... (Enter to send)"
            rows={2}
            disabled={isSending}
            className="flex-1 resize-none bg-slate-800/70 border border-slate-700/50 rounded-xl px-4 py-2.5 text-sm text-white placeholder-slate-500 focus:border-cyan-500/50 focus:ring-2 focus:ring-cyan-500/10 focus:outline-none transition-all disabled:opacity-50"
          />
          <motion.button
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            onClick={handleSend}
            disabled={!input.trim() || isSending}
            className="h-[52px] w-12 flex items-center justify-center bg-gradient-to-br from-cyan-600 to-blue-600 hover:from-cyan-500 hover:to-blue-500 disabled:opacity-40 disabled:cursor-not-allowed rounded-xl text-white shadow-lg shadow-cyan-500/20 transition-all"
          >
            {isSending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
          </motion.button>
        </div>
        <p className="text-[10px] text-slate-600 mt-1.5 text-center">
          Shift+Enter for new line · Every message is defense-checked before response
        </p>
      </div>
    </div>
  );
}
