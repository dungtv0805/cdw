---
description: Run a multi-agent team in the background. Role agents (PM, Architect, Engineer, Reviewer, …) talk to each other over a message bus, debate and bring you only the questions that block them. Use it to write a spec, debate a design, deliver a feature end to end with code review, run a security review or investigate an incident.
argument-hint: <template> <brief>   (feature-delivery | product-design | design-debate | security-review | incident-investigation)
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/bin/dw:*), mcp__plugin_cdw_workflow-bus__bus_poll, mcp__plugin_cdw_workflow-bus__bus_reply, mcp__plugin_cdw_workflow-bus__bus_send, mcp__plugin_cdw_workflow-bus__bus_run, mcp__plugin_cdw_workflow-bus__bus_history, mcp__plugin_cdw_workflow-bus__bus_artifact
---

The user asked to run a dynamic workflow: `$ARGUMENTS`

This command is the user's explicit request to run a workflow: you call the Workflow tool in step 3.

1. **Pick the template.** The first word of the arguments is the template id and the rest is the brief. If the first word is not a template id, run `${CLAUDE_PLUGIN_ROOT}/bin/dw --bus-server plugin_cdw_workflow-bus templates` and pick the template whose "for:" request types fit the brief; say in one line which one you picked.
2. **Prepare the run.** Run `${CLAUDE_PLUGIN_ROOT}/bin/dw --bus-server plugin_cdw_workflow-bus prepare <template> --brief '<brief>'` (single-quote the brief and escape any single quote in it). When the user points at an existing document the team should start from — typically a spec for `feature-delivery` — add `--artifact <name>=<absolute path>` (e.g. `--artifact spec.md=/abs/path/spec.md`); the phase that would write that document is then skipped. It compiles the saved workflow, opens the run on the bus and prints JSON with `runId`, `scriptPath`, `args`, `outputDir`, `team`, `changesWorkspace`, `watch`, `inbox` and `tail`.
   If `changesWorkspace` is true, the team will change files in this project (for `feature-delivery`: implement and commit on the current branch). Before launching, tell the user in one line which branch and that uncommitted changes of their own stay untouched.
3. **Launch.** Call the Workflow tool with `scriptPath` and `args` exactly as printed — `args` is a JSON object, not a string. If the tool rejects that combination, call it with `{name: <workflowName>, args}` instead (the saved workflow in `.claude/workflows`). The workflow runs in the background.
4. **Listen for the team.** Start the printed `watch` command with Bash `run_in_background: true`. It exits — and you get a notification — as soon as a message reaches `main`.
5. **Tell the user** in a few lines: the template, the run id, the team, where results land (`outputDir`, documents under `artifacts/`), and that they can follow the debate live with the printed `tail` command in another terminal.

When the watch task finishes:
- Read the messages: `mcp__plugin_cdw_workflow-bus__bus_poll({runId: "<runId>", agent: "main"})`.
- A **question** (`expectsReply: true`) comes from the team's liaison and has already been debated: answer from this conversation only if the user already decided exactly that; otherwise show the user each question with its options and the team's recommendation, and wait for their answer. Then send it: `mcp__plugin_cdw_workflow-bus__bus_reply({runId: "<runId>", from: "main", replyTo: <seq>, content: "<answer, e.g. 1: a, 2: b>"})`. The team is blocked until this reply arrives.
- A **report** or anything else: summarise it for the user.
- While the workflow is still running, start the `watch` command again in the background.

When the Workflow task completes: summarise the result for the user (status, decisions, open issues, artifacts with their paths under `outputDir`, and for workflows that changed the project the `work` items with their status and changes and the `reviews` verdicts), stop any watch task still running, and offer to open the main artifact. Never answer a team question on the user's behalf unless they already decided it.
