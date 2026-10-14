import { describe, it, expect } from "vitest";
import { computeJourney, currentStepIndex, hasActiveTrigger, type JourneyInput } from "./journey";
import { computeBuildProgress, parseToolStatus, selectBuildTools } from "./build-progress";

const base: JourneyInput = {
  phase: "planning",
  missingCredentials: null,
  hasRun: false,
  isRunning: false,
  isDeployed: false,
};
const states = (i: JourneyInput) => computeJourney(i).map((s) => s.state);

describe("journey", () => {
  it("starts at plan", () => {
    expect(states(base)).toEqual(["active", "todo", "todo", "todo", "todo"]);
  });
  it("building marks plan done", () => {
    expect(states({ ...base, phase: "building" })).toEqual(["done", "active", "todo", "todo", "todo"]);
  });
  it("asks for credentials once built and some are missing", () => {
    expect(currentStepIndex({ ...base, phase: "staging", missingCredentials: 2 })).toBe(2);
  });
  it("moves to test when credentials are connected or unknown", () => {
    expect(currentStepIndex({ ...base, phase: "staging", missingCredentials: 0 })).toBe(3);
    expect(currentStepIndex({ ...base, phase: "staging", missingCredentials: null })).toBe(3);
  });
  it("stays on test while running", () => {
    expect(currentStepIndex({ ...base, phase: "running", isRunning: true })).toBe(3);
  });
  it("treats an active schedule as fully done once built and connected", () => {
    expect(states({ ...base, phase: "staging", missingCredentials: 0, isDeployed: true })).toEqual(["done", "done", "done", "done", "done"]);
  });
  it("still asks for accounts when a schedule exists but credentials are missing", () => {
    expect(currentStepIndex({ ...base, phase: "staging", missingCredentials: 1, isDeployed: true })).toBe(2);
  });
  it("offers deploy after a run, then completes", () => {
    const ran = { ...base, phase: "staging" as const, missingCredentials: 0, hasRun: true };
    expect(currentStepIndex(ran)).toBe(4);
    expect(states({ ...ran, isDeployed: true })).toEqual(["done", "done", "done", "done", "done"]);
  });
});

describe("build progress", () => {
  it("never reaches 100 until finished", () => {
    const tools = Array.from({ length: 500 }, () => ({ name: "write_file", done: true }));
    expect(computeBuildProgress(tools, false).percent).toBeLessThan(100);
    expect(computeBuildProgress(tools, true).percent).toBe(100);
  });
  it("increases monotonically with completed tools", () => {
    const mk = (n: number) => Array.from({ length: n }, () => ({ name: "edit_file", done: true }));
    expect(computeBuildProgress(mk(5), false).percent).toBeGreaterThan(computeBuildProgress(mk(2), false).percent);
  });
  it("labels the in-flight tool in plain words", () => {
    expect(computeBuildProgress([{ name: "write_file", done: false }], false).label).toBe("Writing code");
  });
  it("parses tool_status payloads and tolerates garbage", () => {
    expect(parseToolStatus('{"tools":[{"name":"a","done":true}]}')).toHaveLength(1);
    expect(parseToolStatus("plain text")).toEqual([]);
  });
});

import { missingRequirements, friendlyCredentialName } from "./credential-status";
import type { AgentCredentialRequirement } from "@/api/credentials";

const req = (o: Partial<AgentCredentialRequirement>): AgentCredentialRequirement => ({
  credential_name: "x", credential_id: "x", env_var: "X", description: "", help_url: "", tools: [],
  node_types: [], available: false, valid: null, validation_message: null,
  direct_api_key_supported: true, aden_supported: false, credential_key: "k", alternative_group: null, ...o,
});

describe("credential status", () => {
  it("lists unavailable requirements", () => {
    expect(missingRequirements([req({ available: true }), req({ credential_id: "b" })])).toHaveLength(1);
  });
  it("treats an alternative group as satisfied by any member", () => {
    const r = [req({ alternative_group: "g", available: true }), req({ alternative_group: "g" })];
    expect(missingRequirements(r)).toHaveLength(0);
  });
  it("counts an unsatisfied group once", () => {
    const r = [req({ alternative_group: "g" }), req({ alternative_group: "g" })];
    expect(missingRequirements(r)).toHaveLength(1);
  });
  it("prettifies names", () => {
    expect(friendlyCredentialName({ credential_name: "google_sheets_token", credential_id: "" })).toBe("Google Sheets");
  });
});

describe("selectBuildTools", () => {
  const msg = (tools: { name: string; done: boolean }[], role = "queen") => ({
    type: "tool_status", role, content: JSON.stringify({ tools }),
  });
  it("starts counting at the latest build kickoff and ignores worker tools", () => {
    const out = selectBuildTools([
      msg([{ name: "save_agent_draft", done: true }]),
      msg([{ name: "initialize_and_build_agent", done: true }]),
      msg([{ name: "write_file", done: true }, { name: "edit_file", done: false }]),
      msg([{ name: "web_search", done: true }], "worker"),
    ]);
    expect(out.map((t) => t.name)).toEqual(["initialize_and_build_agent", "write_file", "edit_file"]);
  });
});

describe("hasActiveTrigger", () => {
  it("is true for running or complete trigger nodes", () => {
    expect(hasActiveTrigger([{ nodeType: "trigger", status: "running" }])).toBe(true);
    expect(hasActiveTrigger([{ nodeType: "trigger", status: "complete" }])).toBe(true);
  });
  it("survives the status reset to pending while a countdown is present", () => {
    expect(hasActiveTrigger([{ nodeType: "trigger", status: "pending", triggerConfig: { next_fire_in: 120 } }])).toBe(true);
  });
  it("is false for inactive triggers and ignores execution nodes", () => {
    expect(hasActiveTrigger([{ nodeType: "trigger", status: "pending" }, { nodeType: "execution", status: "running" }])).toBe(false);
  });
});
