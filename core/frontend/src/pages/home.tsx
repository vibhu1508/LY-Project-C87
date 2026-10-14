import { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { Mail, Briefcase, Shield, Search, Newspaper, ArrowRight, Hexagon, Send, Bot, Radar, Reply, DollarSign, MapPin, Calendar, UserPlus, Twitter } from "lucide-react";
import TopBar from "@/components/TopBar";
import { AnimatedGroup } from "@/components/ui/animated-group";
import type { LucideIcon } from "lucide-react";
import { agentsApi } from "@/api/agents";
import type { DiscoverEntry } from "@/api/types";

// --- Icon and color maps (backend can't serve icons) ---

const AGENT_ICONS: Record<string, LucideIcon> = {
  email_inbox_management: Mail,
  job_hunter: Briefcase,
  vulnerability_assessment: Shield,
  deep_research_agent: Search,
  tech_news_reporter: Newspaper,
  competitive_intel_agent: Radar,
  email_reply_agent: Reply,
  hubspot_revenue_leak_detector: DollarSign,
  local_business_extractor: MapPin,
  meeting_scheduler: Calendar,
  sdr_agent: UserPlus,
  twitter_news_agent: Twitter,
};

function agentSlug(path: string): string {
  return path.replace(/\/$/, "").split("/").pop() || path;
}

// --- Generic prompt hints (not tied to specific agents) ---

const promptHints = [
  "Remind me of assignment deadlines every Friday",
  "Summarize my unread emails each morning",
  "Turn lecture videos into study notes",
  "Email my class when homework is posted",
];

export default function Home() {
  const navigate = useNavigate();
  const [inputValue, setInputValue] = useState("");
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const [showAgents, setShowAgents] = useState(false);
  const [agents, setAgents] = useState<DiscoverEntry[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Fetch agents on mount so data is ready when user toggles
  useEffect(() => {
    setLoading(true);
    agentsApi
      .discover()
      .then((result) => {
        const examples = result["Examples"] || [];
        setAgents(examples);
      })
      .catch((err) => {
        setError(err.message || "Failed to load agents");
      })
      .finally(() => {
        setLoading(false);
      });
  }, []);

  const handleSelect = (agentPath: string) => {
    navigate(`/workspace?agent=${encodeURIComponent(agentPath)}`);
  };

  const handlePromptHint = (text: string) => {
    navigate(`/workspace?agent=new-agent&prompt=${encodeURIComponent(text)}`);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (inputValue.trim()) {
      navigate(`/workspace?agent=new-agent&prompt=${encodeURIComponent(inputValue.trim())}`);
    }
  };

  return (
    <div className="min-h-screen flex flex-col">
      <TopBar />

      <div className="flex-1 flex flex-col items-center justify-center p-6">
        <AnimatedGroup className="w-full max-w-2xl" stagger={0.09}>
          <div className="text-center mb-8">
            <div className="inline-flex w-14 h-14 rounded-full items-center justify-center mb-5 glass-strong">
              <Bot className="w-6 h-6 text-foreground" />
            </div>
            <h1 className="text-3xl font-semibold tracking-tight text-foreground mb-2">What would you like to automate?</h1>
            <p className="text-sm text-muted-foreground">
              Describe it in your own words. I'll build it, test it with you, and set it running.
            </p>
          </div>

          <form onSubmit={handleSubmit} className="mb-6">
            <div className="relative glass-strong rounded-3xl focus-within:border-white/30 transition-colors">
              <textarea
                ref={textareaRef}
                rows={1}
                value={inputValue}
                onChange={(e) => {
                  setInputValue(e.target.value);
                  const ta = e.target;
                  ta.style.height = "auto";
                  ta.style.height = `${Math.min(ta.scrollHeight, 160)}px`;
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    handleSubmit(e);
                  }
                }}
                placeholder="e.g. Email me a summary of my assignments every Friday…"
                className="w-full bg-transparent px-6 py-4 pr-16 text-sm text-foreground placeholder:text-muted-foreground/70 focus:outline-none rounded-3xl resize-none overflow-y-auto"
              />
              <div className="absolute right-2.5 bottom-2.5">
                <button
                  type="submit"
                  disabled={!inputValue.trim()}
                  className="w-9 h-9 rounded-full bg-white text-black hover:bg-white/90 flex items-center justify-center transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
                >
                  <Send className="w-4 h-4" />
                </button>
              </div>
            </div>
          </form>

          <div className="flex flex-wrap justify-center gap-2 mb-6">
            {promptHints.map((hint) => (
              <button
                key={hint}
                onClick={() => handlePromptHint(hint)}
                className="text-xs text-muted-foreground hover:text-foreground glass-soft glass-hover rounded-full px-3.5 py-1.5"
              >
                {hint}
              </button>
            ))}
          </div>

          <div className="flex items-center justify-center gap-3 mb-6">
            <button
              onClick={() => setShowAgents(!showAgents)}
              className="inline-flex items-center gap-2 text-sm font-medium px-4 py-2 rounded-full glass glass-hover text-foreground"
            >
              <Hexagon className="w-4 h-4" />
              <span>Browse examples</span>
              <ArrowRight className={`w-3.5 h-3.5 transition-transform duration-200 ${showAgents ? "rotate-90" : ""}`} />
            </button>
            <button
              onClick={() => navigate("/my-agents")}
              className="inline-flex items-center gap-2 text-sm font-medium px-4 py-2 rounded-full glass glass-hover text-foreground"
            >
              <Bot className="w-4 h-4" />
              <span>My agents</span>
            </button>
          </div>

          {showAgents && (
            <div className="animate-in fade-in slide-in-from-bottom-2 duration-300">
              {loading && (
                <div className="text-center py-8 text-sm text-muted-foreground">Loading examples…</div>
              )}
              {error && (
                <div className="text-center py-8 text-sm text-destructive">Couldn't load examples. Please try again.</div>
              )}
              {!loading && !error && agents.length === 0 && (
                <div className="text-center py-8 text-sm text-muted-foreground">No examples available yet.</div>
              )}
              {!loading && !error && agents.length > 0 && (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                  {agents.map((agent) => {
                    const slug = agentSlug(agent.path);
                    const Icon = AGENT_ICONS[slug] || Hexagon;
                    return (
                      <button
                        key={agent.path}
                        onClick={() => handleSelect(agent.path)}
                        className="text-left rounded-3xl glass-soft glass-hover p-4 group relative overflow-hidden h-full flex flex-col"
                      >
                        <div className="flex items-center gap-3 mb-2.5">
                          <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 bg-white/10 border border-white/15">
                            <Icon className="w-4 h-4 text-foreground" />
                          </div>
                          <h3 className="text-sm font-semibold text-foreground">{agent.name}</h3>
                        </div>
                        <p className="text-xs text-muted-foreground leading-relaxed line-clamp-3">
                          {agent.description}
                        </p>
                      </button>
                    );
                  })}
                </div>
              )}
            </div>
          )}
        </AnimatedGroup>
      </div>
    </div>
  );
}
