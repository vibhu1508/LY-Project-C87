import { motion } from "motion/react";
import { useId } from "react";
import { cn } from "@/lib/utils";

export interface SlidingTab {
  id: string;
  label: string;
  onClick: () => void;
  active: boolean;
  badge?: React.ReactNode;
  trailing?: React.ReactNode;
}

/** Navbar-gallery style pill tabs with a shared sliding highlight. */
export function SlidingTabs({ tabs, className }: { tabs: SlidingTab[]; className?: string }) {
  const layoutId = useId();
  return (
    <div className={cn("flex items-center gap-0.5 min-w-0 overflow-x-auto scrollbar-hide", className)}>
      {tabs.map((t) => (
        <button
          key={t.id}
          onClick={t.onClick}
          className={cn(
            "group relative flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-xs font-medium whitespace-nowrap flex-shrink-0 transition-colors",
            t.active ? "text-foreground" : "text-muted-foreground hover:text-foreground",
          )}
        >
          {t.active && (
            <motion.span
              layoutId={layoutId}
              className="absolute inset-0 rounded-full bg-white/12 border border-white/15"
              transition={{ type: "spring", stiffness: 380, damping: 32 }}
            />
          )}
          {t.badge && <span className="relative">{t.badge}</span>}
          <span className="relative">{t.label}</span>
          {t.trailing && <span className="relative">{t.trailing}</span>}
        </button>
      ))}
    </div>
  );
}
