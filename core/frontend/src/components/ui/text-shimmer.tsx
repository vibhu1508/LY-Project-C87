import { cn } from "@/lib/utils";

/** Animated shimmering text — used for "working…" states (Motion Primitives style). */
export function TextShimmer({ children, className }: { children: React.ReactNode; className?: string }) {
  return <span className={cn("text-shimmer", className)}>{children}</span>;
}
