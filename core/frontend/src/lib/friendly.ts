/** Plain-language labels for the technical tool names the agents call. */

const TOOL_LABELS: Record<string, string> = {
  read_file: "Reading files",
  list_directory: "Looking around",
  search_files: "Searching",
  write_file: "Writing code",
  edit_file: "Refining code",
  hashline_edit: "Refining code",
  undo_changes: "Undoing a change",
  run_command: "Running a check",
  list_agent_tools: "Choosing tools",
  validate_agent_package: "Checking everything works",
  list_agents: "Looking at existing agents",
  list_agent_sessions: "Reviewing past runs",
  list_agent_checkpoints: "Reviewing past runs",
  get_agent_checkpoint: "Reviewing past runs",
  save_agent_draft: "Designing the plan",
  confirm_and_build: "Starting the build",
  initialize_and_build_agent: "Setting up your agent",
  load_built_agent: "Loading your agent",
  list_credentials: "Checking connected accounts",
  replan_agent: "Re-thinking the plan",
  get_worker_status: "Checking progress",
  run_agent_with_input: "Starting your agent",
  stop_worker: "Stopping your agent",
  set_trigger: "Setting up a schedule",
  remove_trigger: "Removing a schedule",
  list_triggers: "Checking schedules",
  write_to_diary: "Taking notes",
  recall_diary: "Recalling notes",
  delegate_to_sub_agent: "Asking a helper",
};

export function friendlyToolName(name: string): string {
  return TOOL_LABELS[name] ?? "Working on it";
}

/** Tools that mean "code is being produced" — used to drive the build progress bar. */
const CODE_TOOLS = new Set(["write_file", "edit_file", "hashline_edit"]);
export function isCodeTool(name: string): boolean {
  return CODE_TOOLS.has(name);
}
