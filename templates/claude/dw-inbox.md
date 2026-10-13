---
description: Show what the dynamic-workflow teams are waiting on and answer their questions
allowed-tools: Bash({{DW_BIN}}:*), {{BUS}}bus_poll, {{BUS}}bus_reply, {{BUS}}bus_run
---

Check the dynamic-workflow runs for anything waiting on the user. $ARGUMENTS

1. Run `{{DW}} status` to list the runs with their open questions and unread mail for `main`.
2. Read what is waiting: `{{BUS}}bus_poll({runId: "*", agent: "main"})`. Questions stay listed under "open questions" in `{{DW}} status <run>` until they are answered.
3. Show the user each question with its options and the team's recommendation, and ask for their answer. Send each answer with `{{BUS}}bus_reply({runId: "<run>", from: "main", replyTo: <seq>, content: "<answer>"})`.
4. For reports or results, summarise them; `{{DW}} status <run>` lists the run's artifacts with their paths.
