import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Bot, Activity, Moon, Plus } from "lucide-react";
import TopBar from "@/components/TopBar";
import { agentsApi } from "@/api/agents";
import type { DiscoverEntry } from "@/api/types";

function timeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const seconds = Math.floor(diff / 1000);
  if (seconds < 60) return "Just now";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} hour${hours !== 1 ? "s" : ""} ago`;
  const days = Math.floor(hours / 24);
  return `${days} day${days !== 1 ? "s" : ""} ago`;
}

export default function MyAgents() {
  const navigate = useNavigate();
  const [agents, setAgents] = useState<DiscoverEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    agentsApi
      .discover()
      .then((result) => {
        const entries = result["Your Agents"] || [];
        entries.sort((a, b) => {
          if (!a.last_active && !b.last_active) return 0;
          if (!a.last_active) return 1;
          if (!b.last_active) return -1;
          return b.last_active.localeCompare(a.last_active);
        });
        setAgents(entries);
      })
      .catch((err) => {
        setError(err.message || "Failed to load agents");
      })
      .finally(() => {
        setLoading(false);
      });
  }, []);

  const activeCount = agents.filter((a) => a.is_loaded).length;
  const idleCount = agents.length - activeCount;

  return (
    <div className="h-screen flex flex-col overflow-hidden">
      <TopBar />

      {/* Content */}
      <div className="flex-1 p-6 md:p-10 max-w-5xl mx-auto w-full overflow-y-auto">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight text-foreground">My agents</h1>
            <p className="text-sm text-muted-foreground mt-1">
              {activeCount} running · {idleCount} resting
            </p>
          </div>
          <button
            onClick={() => navigate("/workspace?agent=new-agent")}
            className="flex items-center gap-2 px-4 py-2 rounded-full bg-white text-black text-sm font-medium hover:bg-white/90 transition-colors"
          >
            <Plus className="w-4 h-4" />
            New agent
          </button>
        </div>

        {loading && (
          <div className="text-center py-16 text-sm text-muted-foreground">Loading your agents…</div>
        )}
        {error && (
          <div className="text-center py-16 text-sm text-destructive">Couldn't load your agents. Please try again.</div>
        )}
        {!loading && !error && agents.length === 0 && (
          <div className="text-center py-16 text-sm text-muted-foreground">You haven't created any agents yet — start one above.</div>
        )}

        {!loading && !error && agents.length > 0 && (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {agents.map((agent) => (
              <button
                key={agent.path}
                onClick={() => navigate(`/workspace?agent=${encodeURIComponent(agent.path)}`)}
                className="group text-left rounded-3xl glass glass-hover p-5"
              >
                <div className="flex items-start justify-between mb-3">
                  <div className="p-2 rounded-full bg-white/10">
                    <Bot className="w-4 h-4 text-muted-foreground group-hover:text-foreground transition-colors" />
                  </div>
                  <div className="flex items-center gap-1.5">
                    {agent.is_loaded ? (
                      <>
                        <span className="relative flex h-2 w-2">
                          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-white opacity-50" />
                          <span className="relative inline-flex rounded-full h-2 w-2 bg-white" />
                        </span>
                        <span className="text-xs font-medium text-foreground">Running</span>
                      </>
                    ) : (
                      <>
                        <Moon className="w-3 h-3 text-muted-foreground" />
                        <span className="text-xs text-muted-foreground">Resting</span>
                      </>
                    )}
                  </div>
                </div>

                <h3 className="text-sm font-semibold text-foreground mb-1 group-hover:text-foreground transition-colors">
                  {agent.name}
                </h3>
                <p className="text-xs text-muted-foreground leading-relaxed mb-4 line-clamp-2">
                  {agent.description}
                </p>

                <div className="flex items-center justify-between text-xs text-muted-foreground">
                  <div className="flex items-center gap-1">
                    <Activity className="w-3 h-3" />
                    <span>
                      {agent.run_count} run{agent.run_count !== 1 ? "s" : ""}
                    </span>
                  </div>
                  <span>{agent.last_active ? timeAgo(agent.last_active) : "Never run"}</span>
                </div>
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
