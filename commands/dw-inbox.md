---
description: Show what your multi-agent teams are waiting on and answer their blocking questions
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/bin/dw:*), mcp__plugin_cdw_workflow-bus__bus_poll, mcp__plugin_cdw_workflow-bus__bus_reply, mcp__plugin_cdw_workflow-bus__bus_run
---

Check the dynamic-workflow runs for anything waiting on the user. $ARGUMENTS

1. Run `${CLAUDE_PLUGIN_ROOT}/bin/dw --bus-server plugin_cdw_workflow-bus status` to list the runs with their open questions and unread mail for `main`.
2. Read what is waiting: `mcp__plugin_cdw_workflow-bus__bus_poll({runId: "*", agent: "main"})`. Questions stay listed under "open questions" in `${CLAUDE_PLUGIN_ROOT}/bin/dw --bus-server plugin_cdw_workflow-bus status <run>` until they are answered.
3. Show the user each question with its options and the team's recommendation, and ask for their answer. Send each answer with `mcp__plugin_cdw_workflow-bus__bus_reply({runId: "<run>", from: "main", replyTo: <seq>, content: "<answer>"})`.
4. For reports or results, summarise them; `${CLAUDE_PLUGIN_ROOT}/bin/dw --bus-server plugin_cdw_workflow-bus status <run>` lists the run's artifacts with their paths.
