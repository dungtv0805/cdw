---
description: Show what your multi-agent teams are waiting on and answer their blocking questions
allowed-tools: Bash({{DW_BIN}}:*), {{BUS}}bus_run
---

Check the dynamic-workflow runs for anything waiting on the user. $ARGUMENTS

1. Run `{{DW}} status` to list the runs with their open questions and unread mail for `main`.
2. Read what is waiting: `{{DW}} inbox --mark-read` (every open run). The bus tools never act as `main`: you read and answer for the user through `{{DW}}`. Questions stay listed under "open questions" in `{{DW}} status <run>` until they are answered.
3. Show the user each question with its options and the team's recommendation, and ask for their answer. Send each answer with `{{DW}} reply <run> <seq> '<answer>'`; an agent relaying the user's answer adds `--via <its name>`.
4. For reports or results, summarise them; `{{DW}} status <run>` lists the run's artifacts with their paths.
