import { memo, useState } from "react";
import { Play, Pause, Loader2, CheckCircle2 } from "lucide-react";
import type { RunButtonProps } from "./graph-types";

export const RunButton = memo(function RunButton({ runState, disabled, onRun, onPause, btnRef }: RunButtonProps) {
  const [hovered, setHovered] = useState(false);
  const showPause = runState === "running" && hovered;

  return (
    <button
      ref={btnRef}
      onClick={runState === "running" ? onPause : onRun}
      disabled={runState === "deploying" || disabled}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      className={`flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-semibold transition-all duration-200 ${
        showPause
          ? "bg-white/15 text-foreground border border-white/30 hover:bg-white/25 active:scale-95 cursor-pointer"
          : runState === "running"
          ? "bg-white/10 text-foreground border border-white/20 cursor-pointer"
          : runState === "deploying"
          ? "bg-white/10 text-foreground border border-white/15 cursor-default"
          : disabled
          ? "bg-white/5 text-muted-foreground/40 border border-white/10 cursor-not-allowed"
          : "bg-white text-black border border-white hover:bg-white/90 active:scale-95"
      }`}
    >
      {runState === "deploying" ? (
        <Loader2 className="w-3 h-3 animate-spin" />
      ) : showPause ? (
        <Pause className="w-3 h-3 fill-current" />
      ) : runState === "running" ? (
        <CheckCircle2 className="w-3 h-3" />
      ) : (
        <Play className="w-3 h-3 fill-current" />
      )}
      {runState === "deploying" ? "Starting\u2026" : showPause ? "Pause" : runState === "running" ? "Running" : "Run"}
    </button>
  );
});
