import { useEffect, useMemo, useState } from "react";
import { AnimatePresence, motion } from "motion/react";
import { Check, KeyRound, Loader2, Pause, Play, Rocket, CheckCircle2 } from "lucide-react";
import { credentialsApi } from "@/api/credentials";
import { computeBuildProgress, selectBuildTools } from "@/lib/build-progress";
import { friendlyCredentialName, missingRequirements } from "@/lib/credential-status";
import { computeJourney, type QueenPhase } from "@/lib/journey";
import { GlassProgress } from "@/components/ui/glass-progress";
import { TextShimmer } from "@/components/ui/text-shimmer";
import type { ChatMessage } from "@/components/ChatPanel";
import { cn } from "@/lib/utils";

/** Sessions we have already auto-prompted for credentials — survives remounts (tab switches). */
const promptedSessions = new Set<string>();

interface JourneyBarProps {
  phase: QueenPhase;
  runState: "idle" | "deploying" | "running";
  messages: ChatMessage[];
  sessionId: string | null;
  agentPath: string | null;
  /** Bump to re-check credentials (e.g. after the credentials modal closes). */
  credentialsRefreshKey: number;
  /** True when a schedule/trigger for the agent is active. */
  isDeployed: boolean;
  disabled?: boolean;
  onOpenCredentials: () => void;
  onRun: () => void;
  onPause: () => void;
  onDeploy: () => void;
}

export default function JourneyBar({
  phase,
  runState,
  messages,
  sessionId,
  agentPath,
  credentialsRefreshKey,
  isDeployed,
  disabled,
  onOpenCredentials,
  onRun,
  onPause,
  onDeploy,
}: JourneyBarProps) {
  const [missing, setMissing] = useState<string[] | null>(null);
  const built = phase === "staging" || phase === "running";

  // Which accounts does the finished agent still need?
  useEffect(() => {
    if (!built || !agentPath) {
      setMissing(null);
      return;
    }
    let cancelled = false;
    credentialsApi
      .checkAgent(agentPath)
      .then(({ required }) => {
        if (!cancelled) setMissing(missingRequirements(required).map(friendlyCredentialName));
      })
      .catch(() => {
        if (!cancelled) setMissing(null);
      });
    return () => {
      cancelled = true;
    };
  }, [built, agentPath, credentialsRefreshKey]);

  // Ask for credentials once, right after the build finishes (never repeatedly).
  useEffect(() => {
    if (phase !== "staging" || !sessionId || !missing || missing.length === 0) return;
    if (promptedSessions.has(sessionId)) return;
    promptedSessions.add(sessionId);
    onOpenCredentials();
  }, [phase, sessionId, missing, onOpenCredentials]);

  const hasRun = useMemo(
    () => runState === "running" || messages.some((m) => m.type === "run_divider"),
    [runState, messages],
  );
  const buildTools = useMemo(
    () => (phase === "building" ? selectBuildTools(messages) : []),
    [phase, messages],
  );

  const steps = computeJourney({
    phase,
    missingCredentials: missing ? missing.length : null,
    hasRun,
    isRunning: runState === "running",
    isDeployed,
  });
  const active = steps.find((s) => s.state === "active")?.id;
  const progress = computeBuildProgress(buildTools, phase !== "building");

  return (
    <div className="px-4 pt-2 space-y-2">
      <ol className="glass rounded-full px-3 py-2 flex items-center justify-between gap-1 text-xs">
        {steps.map((s, i) => (
          <li key={s.id} className="flex items-center gap-1 flex-1 min-w-0 last:flex-none">
            <span
              className={cn(
                "flex items-center gap-1.5 px-2.5 py-1 rounded-full transition-colors whitespace-nowrap",
                s.state === "active" && "bg-white text-black font-semibold",
                s.state === "done" && "text-foreground",
                s.state === "todo" && "text-muted-foreground/60",
              )}
            >
              {s.state === "done" ? (
                <Check className="w-3 h-3" />
              ) : (
                <span className="text-[10px] tabular-nums opacity-70">{i + 1}</span>
              )}
              {s.label}
            </span>
            {i < steps.length - 1 && (
              <span className={cn("h-px flex-1 min-w-2", s.state === "done" ? "bg-white/40" : "bg-white/10")} />
            )}
          </li>
        ))}
      </ol>

      <AnimatePresence mode="wait" initial={false}>
        {active === "build" && (
          <Card key="build">
            <div className="flex items-center justify-between text-sm">
              <TextShimmer>{progress.label}…</TextShimmer>
              <span className="tabular-nums text-muted-foreground text-xs">{progress.percent}%</span>
            </div>
            <GlassProgress value={progress.percent} className="mt-2" />
            <p className="mt-2 text-xs text-muted-foreground">Building your agent. This usually takes a few minutes.</p>
          </Card>
        )}

        {active === "connect" && (
          <Card key="connect">
            <div className="flex items-center gap-3">
              <KeyRound className="w-4 h-4 text-foreground flex-shrink-0" />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium">Your agent is built — connect your accounts</p>
                <p className="text-xs text-muted-foreground truncate">
                  Needs: {(missing ?? []).join(", ")}
                </p>
              </div>
              <PillButton onClick={onOpenCredentials}>Connect</PillButton>
            </div>
          </Card>
        )}

        {active === "test" && (
          <Card key="test">
            <div className="flex items-center gap-3">
              {runState === "running" ? (
                <Loader2 className="w-4 h-4 animate-spin flex-shrink-0" />
              ) : (
                <Play className="w-4 h-4 flex-shrink-0" />
              )}
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium">
                  {runState === "running" ? "Testing your agent…" : "Ready to test"}
                </p>
                <p className="text-xs text-muted-foreground">
                  {runState === "running"
                    ? "You can pause at any time."
                    : "Run it once to make sure it does what you want."}
                </p>
              </div>
              {runState === "running" ? (
                <PillButton onClick={onPause}>
                  <Pause className="w-3 h-3 fill-current" /> Pause
                </PillButton>
              ) : (
                <PillButton onClick={onRun} disabled={disabled || runState === "deploying"}>
                  {runState === "deploying" ? <Loader2 className="w-3 h-3 animate-spin" /> : <Play className="w-3 h-3 fill-current" />}
                  Test it
                </PillButton>
              )}
            </div>
          </Card>
        )}

        {active === "deploy" && (
          <Card key="deploy">
            <div className="flex items-center gap-3">
              <Rocket className="w-4 h-4 flex-shrink-0" />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium">Happy with the result?</p>
                <p className="text-xs text-muted-foreground">Deploy it so it runs automatically on a schedule.</p>
              </div>
              <PillButton onClick={onRun} disabled={disabled} subtle>
                Run again
              </PillButton>
              <PillButton onClick={onDeploy} disabled={disabled}>
                Deploy
              </PillButton>
            </div>
          </Card>
        )}

        {isDeployed && active === undefined && (
          <Card key="live">
            <div className="flex items-center gap-3 text-sm">
              <CheckCircle2 className="w-4 h-4" />
              <span className="font-medium">Your agent is live</span>
            </div>
          </Card>
        )}
      </AnimatePresence>
    </div>
  );
}

function Card({ children }: { children: React.ReactNode }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: -8, scale: 0.98 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: -8, scale: 0.98 }}
      transition={{ duration: 0.2 }}
      className="glass rounded-3xl px-4 py-3"
    >
      {children}
    </motion.div>
  );
}

function PillButton({
  children,
  onClick,
  disabled,
  subtle,
}: {
  children: React.ReactNode;
  onClick: () => void;
  disabled?: boolean;
  subtle?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={cn(
        "flex items-center gap-1.5 rounded-full px-4 py-1.5 text-xs font-semibold transition-all active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed flex-shrink-0",
        subtle ? "glass-soft text-foreground hover:bg-white/15" : "bg-white text-black hover:bg-white/90",
      )}
    >
      {children}
    </button>
  );
}
