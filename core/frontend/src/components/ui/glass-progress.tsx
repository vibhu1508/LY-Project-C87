import { motion } from "motion/react";
import { cn } from "@/lib/utils";

/** Glass progress bar with an animated fill. */
export function GlassProgress({ value, className }: { value: number; className?: string }) {
  const pct = Math.max(0, Math.min(100, value));
  return (
    <div
      role="progressbar"
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={Math.round(pct)}
      className={cn("h-2 w-full overflow-hidden rounded-full bg-white/10 border border-white/10", className)}
    >
      <motion.div
        className="h-full rounded-full bg-gradient-to-r from-white/60 to-white"
        initial={false}
        animate={{ width: `${pct}%` }}
        transition={{ type: "spring", stiffness: 80, damping: 20 }}
      />
    </div>
  );
}
