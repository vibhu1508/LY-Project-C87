export type QueenPhase = "planning" | "building" | "staging" | "running";
export type StepId = "plan" | "build" | "connect" | "test" | "deploy";
export type StepState = "done" | "active" | "todo";

export interface JourneyInput {
  phase: QueenPhase;
  /** Number of required accounts not yet connected; null while unknown. */
  missingCredentials: number | null;
  /** True once the agent has been run at least once in this session. */
  hasRun: boolean;
  /** True while a run is in progress. */
  isRunning: boolean;
  /** True when a schedule/trigger for the agent is active. */
  isDeployed: boolean;
}

export interface JourneyStep {
  id: StepId;
  label: string;
  state: StepState;
}

export const STEP_LABELS: Record<StepId, string> = {
  plan: "Plan",
  build: "Build",
  connect: "Connect",
  test: "Test",
  deploy: "Deploy",
};

const ORDER: StepId[] = ["plan", "build", "connect", "test", "deploy"];

/** Index of the step the user is currently on (ORDER.length = everything done). */
export function currentStepIndex(i: JourneyInput): number {
  if (i.phase === "planning") return 0;
  if (i.phase === "building") return 1;
  // Agent is built (staging / running). A live schedule means every step is done.
  if (i.isDeployed && !i.isRunning && (i.missingCredentials ?? 0) === 0) return ORDER.length;
  if ((i.missingCredentials ?? 0) > 0 && !i.hasRun && !i.isRunning) return 2;
  if (!i.hasRun && !i.isRunning) return 3;
  if (i.isRunning) return 3;
  if (!i.isDeployed) return 4;
  return ORDER.length;
}

export function computeJourney(input: JourneyInput): JourneyStep[] {
  const cur = currentStepIndex(input);
  return ORDER.map((id, idx) => ({
    id,
    label: STEP_LABELS[id],
    state: idx < cur ? "done" : idx === cur ? "active" : "todo",
  }));
}

interface TriggerLike {
  nodeType?: string;
  status: string;
  triggerConfig?: Record<string, unknown>;
}

/**
 * A schedule counts as live when a trigger node is running/complete, or still
 * carries a next-fire countdown. The countdown is checked too because
 * `execution_started` resets every node's status to "pending", including triggers.
 */
export function hasActiveTrigger(nodes: TriggerLike[]): boolean {
  return nodes.some(
    (n) =>
      n.nodeType === "trigger" &&
      (n.status === "running" || n.status === "complete" || typeof n.triggerConfig?.next_fire_in === "number"),
  );
}
