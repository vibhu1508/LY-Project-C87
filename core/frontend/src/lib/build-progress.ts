import { friendlyToolName } from "./friendly";

export interface ToolEntry {
  name: string;
  done: boolean;
}

export interface BuildProgress {
  /** 0–100. Eases toward but never reaches 100 until the build phase ends. */
  percent: number;
  /** Plain-language description of what is happening right now. */
  label: string;
  /** Completed tool calls so far. */
  completed: number;
}

/**
 * The backend gives no total number of build steps, so progress is an
 * asymptotic curve over completed tool calls: fast at first, slower later,
 * never 100% until the caller passes `finished`.
 */
export function computeBuildProgress(tools: ToolEntry[], finished: boolean): BuildProgress {
  const completed = tools.filter((t) => t.done).length;
  if (finished) return { percent: 100, label: "Your agent is ready", completed };
  const percent = Math.min(95, Math.round(95 * (1 - Math.exp(-completed / 14))));
  const active = [...tools].reverse().find((t) => !t.done);
  const last = tools[tools.length - 1];
  const label = active
    ? friendlyToolName(active.name)
    : last
      ? friendlyToolName(last.name)
      : "Getting started";
  return { percent, label, completed };
}

/** Parse the JSON payload stored in `tool_status` chat messages. */
export function parseToolStatus(content: string): ToolEntry[] {
  try {
    const parsed = JSON.parse(content);
    return Array.isArray(parsed.tools) ? parsed.tools : [];
  } catch {
    return [];
  }
}

interface ToolStatusMessage {
  type?: string;
  content: string;
  role?: string;
}

/**
 * Tool calls that belong to the current build: everything from the most recent
 * `initialize_and_build_agent` call onward. Falls back to all queen tool calls
 * if the build start can't be found (e.g. a restored session).
 */
export function selectBuildTools(messages: ToolStatusMessage[]): ToolEntry[] {
  const all: ToolEntry[] = [];
  let startAt = 0;
  for (const m of messages) {
    if (m.type !== "tool_status" || m.role === "worker") continue;
    const tools = parseToolStatus(m.content);
    if (tools.some((t) => t.name === "initialize_and_build_agent")) startAt = all.length;
    all.push(...tools);
  }
  return all.slice(startAt);
}
