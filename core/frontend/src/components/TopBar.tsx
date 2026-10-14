import { useState, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Hexagon, X, SlidersHorizontal } from "lucide-react";
import { SlidingTabs } from "@/components/ui/sliding-tabs";
import { useShowDetails } from "@/hooks/use-details-mode";
import { sessionsApi } from "@/api/sessions";
import { loadPersistedTabs, savePersistedTabs, TAB_STORAGE_KEY, type PersistedTabState } from "@/lib/tab-persistence";

export interface TopBarTab {
  agentType: string;
  label: string;
  isActive: boolean;
  hasRunning: boolean;
}

interface TopBarProps {
  /** Live tabs from workspace state. When omitted, reads from localStorage. */
  tabs?: TopBarTab[];
  /** Called when a tab is clicked (workspace overrides to setActiveWorker). */
  onTabClick?: (agentType: string) => void;
  /** Called when a tab's X is clicked (workspace overrides for SSE teardown). */
  onCloseTab?: (agentType: string) => void;
  /** Whether close buttons are shown. Defaults to true when >1 tab. */
  canCloseTabs?: boolean;
  /** Content rendered right after the tab strip (e.g. + button). */
  afterTabs?: React.ReactNode;
  /** Right-side slot for page-specific controls (e.g. credentials). */
  children?: React.ReactNode;
}

export default function TopBar({ tabs: tabsProp, onTabClick, onCloseTab, canCloseTabs, afterTabs, children }: TopBarProps) {
  const navigate = useNavigate();

  // Fallback: read persisted tabs when no live tabs provided
  const [persisted, setPersisted] = useState<PersistedTabState | null>(() =>
    tabsProp ? null : loadPersistedTabs()
  );

  const tabs: TopBarTab[] = tabsProp ?? deriveTabs(persisted);
  const showClose = canCloseTabs ?? true;

  const handleTabClick = useCallback((agentType: string) => {
    if (onTabClick) {
      onTabClick(agentType);
    } else {
      navigate(`/workspace?agent=${encodeURIComponent(agentType)}`);
    }
  }, [onTabClick, navigate]);

  const handleCloseTab = useCallback((agentType: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (onCloseTab) {
      onCloseTab(agentType);
      return;
    }
    // Kill the backend session (queen/worker) even outside workspace
    sessionsApi.list()
      .then(({ sessions }) => {
        const match = sessions.find(s => s.agent_path.endsWith(agentType));
        if (match) return sessionsApi.stop(match.session_id);
      })
      .catch(() => {});  // fire-and-forget

    // Fallback: update localStorage directly (non-workspace pages)
    setPersisted(prev => {
      if (!prev) return null;
      const nextTabs = prev.tabs.filter(t => t.agentType !== agentType);
      if (nextTabs.length === 0) {
        localStorage.removeItem(TAB_STORAGE_KEY);
        return null;
      }
      const removedIds = new Set(prev.tabs.filter(t => t.agentType === agentType).map(t => t.id));
      const nextSessions = { ...prev.sessions };
      for (const id of removedIds) delete nextSessions[id];
      const nextActiveSession = { ...prev.activeSessionByAgent };
      delete nextActiveSession[agentType];
      const nextActiveWorker = prev.activeWorker === agentType
        ? nextTabs[0].agentType
        : prev.activeWorker;
      const nextState: PersistedTabState = {
        tabs: nextTabs,
        activeSessionByAgent: nextActiveSession,
        activeWorker: nextActiveWorker,
        sessions: nextSessions,
      };
      savePersistedTabs(nextState);
      return nextState;
    });
  }, [onCloseTab]);

  const [showDetails, setShowDetails] = useShowDetails();

  return (
    <div className="relative z-20 flex-shrink-0 px-4 pt-3 pb-1">
      <div className="glass flex h-12 items-center justify-between gap-3 rounded-full px-3 pl-4">
        <div className="flex items-center gap-3 min-w-0">
          <button onClick={() => navigate("/")} className="flex items-center gap-2 hover:opacity-80 transition-opacity flex-shrink-0">
            <Hexagon className="w-4 h-4 text-foreground" />
            <span className="text-sm font-semibold tracking-tight text-foreground">TeamAgents</span>
          </button>

          {tabs.length > 0 && (
            <>
              <span className="h-4 w-px bg-white/15 flex-shrink-0" />
              <SlidingTabs
                tabs={tabs.map((tab) => ({
                  id: tab.agentType,
                  label: tab.label,
                  active: tab.isActive,
                  onClick: () => handleTabClick(tab.agentType),
                  badge: tab.hasRunning ? (
                    <span className="relative flex h-1.5 w-1.5 flex-shrink-0">
                      <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-white opacity-60" />
                      <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-white" />
                    </span>
                  ) : undefined,
                  trailing: showClose ? (
                    <X
                      className="w-3 h-3 opacity-0 group-hover:opacity-60 hover:!opacity-100 transition-opacity"
                      onClick={(e) => handleCloseTab(tab.agentType, e)}
                    />
                  ) : undefined,
                }))}
              />
              {afterTabs}
            </>
          )}
        </div>

        <div className="flex items-center gap-1 flex-shrink-0">
          {children}
          <button
            onClick={() => setShowDetails(!showDetails)}
            aria-pressed={showDetails}
            title="Show technical details (tool activity, logs, usage)"
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
              showDetails ? "bg-white/15 text-foreground" : "text-muted-foreground hover:text-foreground hover:bg-white/8"
            }`}
          >
            <SlidersHorizontal className="w-3.5 h-3.5" />
            Details
          </button>
        </div>
      </div>
    </div>
  );
}

/** Derive TopBarTab[] from persisted localStorage state (used outside workspace). */
function deriveTabs(persisted: PersistedTabState | null): TopBarTab[] {
  if (!persisted) return [];
  const seen = new Set<string>();
  const tabs: TopBarTab[] = [];
  for (const tab of persisted.tabs) {
    if (seen.has(tab.agentType)) continue;
    seen.add(tab.agentType);
    const sessionData = persisted.sessions?.[tab.id];
    const hasRunning = sessionData?.graphNodes?.some(
      (n) => n.status === "running" || n.status === "looping"
    ) ?? false;
    tabs.push({
      agentType: tab.agentType,
      label: tab.label,
      isActive: false, // no active tab outside workspace
      hasRunning,
    });
  }
  return tabs;
}
