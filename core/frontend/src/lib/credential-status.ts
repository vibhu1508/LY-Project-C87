import type { AgentCredentialRequirement } from "@/api/credentials";

/**
 * Requirements that still need the user's attention. Requirements sharing an
 * `alternative_group` are interchangeable, so the group is satisfied as soon as
 * any one of them is available.
 */
export function missingRequirements(required: AgentCredentialRequirement[]): AgentCredentialRequirement[] {
  const satisfiedGroups = new Set(
    required.filter((r) => r.alternative_group && r.available).map((r) => r.alternative_group),
  );
  const seenGroups = new Set<string>();
  const out: AgentCredentialRequirement[] = [];
  for (const r of required) {
    if (r.available) continue;
    if (r.alternative_group) {
      if (satisfiedGroups.has(r.alternative_group) || seenGroups.has(r.alternative_group)) continue;
      seenGroups.add(r.alternative_group);
    }
    out.push(r);
  }
  return out;
}

/** Turn "google_sheets" / "GOOGLE_SHEETS_TOKEN" style names into "Google Sheets". */
export function friendlyCredentialName(r: Pick<AgentCredentialRequirement, "credential_name" | "credential_id">): string {
  const raw = (r.credential_name || r.credential_id || "").replace(/_(api_)?(key|token|secret)$/i, "");
  return raw
    .split(/[_\s-]+/)
    .filter(Boolean)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(" ");
}
