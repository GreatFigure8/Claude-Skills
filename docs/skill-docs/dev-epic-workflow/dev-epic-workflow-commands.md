# dev-epic-workflow

Jonathan's development process for any code change — plan first as an epic, one branch and one executor context per work item, commit early and often, verify what actually landed. Use whenever work involves writing, changing, refactoring, or shipping code in his repos (FastAPI/FastMCP, Oracle Fusion MCP tooling, OIC, Next.js, OCI, Supabase), or on "plan", "epic", "work item", "branch", "PR", "let's build", "refactor", "migrate". Also trigger for issue intake — picking up or filing GitHub issues / Azure DevOps work items ("pick up issue 123", "AB#", "file this as a bug", "/intake") — and for orchestrated execution — dispatching, monitoring, cancelling, or reconciling a work-item-executor subagent, status.json, "orchestrator", "is it blocked". Also for resuming an in-flight epic, verifying a step landed, merging approved PRs, deleting merged branches, and when context is filling or has compacted — "handoff", "checkpoint", "resume where we left off", "/clear", "new session", parallel sessions, git worktrees.

## Prompts

These prompts provide you with a definitive way of interacting with the dev-epic-workflow skill. You can use them or create your own.

### Default Dispatch Prompt

_dispatch 3 work items. If three are not available, then 2. If 2 are not available 1. If there are none available, just stop. you are to /handoff when whatever you dispatch initially is complete. Look at /Users/jonathanstevenson/Source/Oracle-Simple-Convert/docs/EPICS/handoff.md file for reference to what should be next. Execute work items that block others first. When the dispatched item is verified and pr'd, run /handoff. Remember to be quite during execution unless there is a blocker you need me to get past. Remember to use Sonnet 5 for mundane tasks that do not need deep thinking. Opus 5 should be used for all deep thinking tasks._

### Default Intake Prompt

_Please /intake any issues that have not been assigned an epic. remember, you are intake and not a coder. DO NOT DISPATCH ANY CODING AGENTS OR WORK ON ANY CODE. please complete the intake and stop. remember to not be wordy and only talk if you need my attention. Dispatch first. Use sonnet 5 for mundane tasks. Opus 5 should be used for all deep thinking tasks. Also, remember to stay quite and communicate only when there is a blocker, question or issue you need me to rectify. That way, we can save tokens to have fun with later. And remember to have fun._

## Alternate Prompts

The are alternate prompts for you to try in the event the default ones do not meet your needs.

### Dispatch 1 Work Item at a Time

_dispatch 1 work item. If there are none available, just stop. you are to /handoff when whatever you dispatch initially is complete. Look at /Users/jonathanstevenson/Source/Oracle-Simple-Convert/docs/EPICS/handoff.md file for reference to what should be next. Execute work items that block others first. When the dispatched item is verified and pr'd, run /handoff. Remember to be quite during execution unless there is a blocker you need me to get past. Remember to use Sonnet 5 for mundane tasks that do not need deep thinking. Opus 5 should be used for all deep thinking tasks._
