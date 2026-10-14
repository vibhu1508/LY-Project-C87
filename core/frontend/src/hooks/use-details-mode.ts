import { useSyncExternalStore } from "react";

const KEY = "teamagents.showDetails";
const listeners = new Set<() => void>();

function read(): boolean {
  try {
    return localStorage.getItem(KEY) === "1";
  } catch {
    return false;
  }
}

let current = read();

function subscribe(cb: () => void) {
  listeners.add(cb);
  return () => listeners.delete(cb);
}

export function setShowDetails(next: boolean) {
  current = next;
  try {
    localStorage.setItem(KEY, next ? "1" : "0");
  } catch {
    /* storage unavailable — keep in-memory value */
  }
  listeners.forEach((l) => l());
}

/** "Show details" reveals the technical views (tool activity, token usage, node logs). Off by default. */
export function useShowDetails(): [boolean, (v: boolean) => void] {
  const v = useSyncExternalStore(subscribe, () => current, () => false);
  return [v, setShowDetails];
}
