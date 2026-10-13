# cdw: Claude Dynamic Workflow

**Teams of role agents that debate, decide and deliver, inside Claude Code.**

cdw turns one request into a background *dynamic workflow* in Claude Code. A team of role agents (PM, Architect, Engineer, Reviewer, and others) works through a fixed sequence of phases. Inside each phase the agents talk to each other live over an MCP message bus, settle what they can among themselves, and bring you only the questions that block them. No API keys and no SDK: every agent is Claude Code itself, with your skills, your tools and your permissions.

```text
/dw feature-delivery Add a --json flag to the doctor command
```

From that one line:
- PM, Architect and Engineer explore the request and align on scope and approach.
- The PM writes `spec.md`, and the Architect and Engineer approve it.
- The Architect splits the work into small items in `plan.md`.
- The Engineer implements and commits each item, test first.
- An independent Reviewer checks the delivered commits until it approves.

You get the spec, the plan, the commits and the review verdict. Nothing is pushed.

## Highlights

- **A real team conversation.** Agents message one peer, several, everyone (`*`), a group (`@builders`) or a topic (`#decisions`). They wait until every peer has spoken (fan-in), and they ask and get replies, all over the `workflow-bus` MCP server.
- **Debate until consensus.** Rounds stop as soon as every member agrees. Disagreements that remain blocking become questions for you.
- **One batch of questions, with options.** A Liaison collects blocking questions and sends them to you in one message. Each question comes with options, trade-offs and the team's recommendation. Unanswered questions fall back to the recommendation.
- **End-to-end delivery.** `plan` turns a document into ordered work items, `execute` gives each item a fresh agent that works in your repository, and `review` loops reviewer checks and owner fixes until approval.
- **Templates are JSON.** An agent template is a role: its skills per phase, how it works, its rules, and its context by level. A workflow template is a request type: its team, its phases and when to escalate. Override them per project.
- **Your skills, per phase.** Agents load the Claude Code skills each template names, for example `superpowers:test-driven-development` while implementing. A skill that is not installed is applied from its description instead.
- **Observable.** Follow a run live with `dw tail <run> --follow`, inspect it with `dw status`, and export the transcript with `dw export`.

## Install

**For every project** (user scope, the default):

```bash
curl -fsSL https://raw.githubusercontent.com/dungtv0805/cdw/main/install.sh | bash
```

**For one project only** (project scope). Run this inside the project:

```bash
curl -fsSL https://raw.githubusercontent.com/dungtv0805/cdw/main/install.sh | bash -s -- --scope project
```

Requirements:
- macOS or Linux (on Windows, use WSL);
- Node.js 20 or newer;
- Claude Code, with **Dynamic workflows** enabled in `/config`.

Both scopes install cdw into `~/.cdw/app` and link `dw` and `dw-bus` into `~/.local/bin`. Then:

| Scope | `/dw` commands | `workflow-bus` MCP server | Best for |
|-------|----------------|---------------------------|----------|
| `user` (default) | `~/.claude/commands/` | registered for every project (`claude mcp add-json … --scope user`) | using cdw everywhere on your machine |
| `project` | `<project>/.claude/commands/` | `<project>/.mcp.json`, plus `.gitignore` entries and the saved workflows | one repository on this machine (the files hold this machine's paths: each teammate runs the installer) |
| `none` | not installed | not registered | only the `dw` CLI; run `dw setup` or `dw init` later |

Each project keeps its runs in its own `.dw/`. Restart Claude Code after installing.

| Variable | Default | Meaning |
|----------|---------|---------|
| `CDW_SCOPE` | `user` | `user`, `project` or `none` (`--scope` wins) |
| `CDW_HOME` | `~/.cdw` | install directory |
| `CDW_BIN_DIR` | `~/.local/bin` | where `dw` and `dw-bus` are linked |
| `CDW_REF` | `main` | branch or tag to install |

- **Update:** run the same command again.
- **Uninstall:** `curl -fsSL https://raw.githubusercontent.com/dungtv0805/cdw/main/install.sh | bash -s -- --uninstall`.
- **Switch scope later:** `dw setup` wires every project, and `dw init` wires the current one.
- **Other ways to install** (for example from a tarball): see [INSTALL.md](INSTALL.md).

## Quick start

1. Open any project in Claude Code.
2. Run a workflow: `/dw <template> <what you want>`. For example: `/dw feature-delivery Add rate limiting to the login endpoint`.
3. If the team needs a decision, Claude shows you the question with its options. Answer in the chat, for example `1: a`.
4. Follow along from another terminal: `dw tail <run> --follow`.
5. Find the results:
   - documents in `.dw/runs/<run>/artifacts/`;
   - for `feature-delivery`, the commits on your current branch;
   - a summary from Claude when the run ends.

To start from a document you already have, for example a spec, say where it is: `/dw feature-delivery Implement the spec at /abs/path/spec.md`. The file is handed to the team, and the phase that would write it is skipped.

## Workflows

| Template | Team | Use it when | Delivers |
|----------|------|-------------|----------|
| `feature-delivery` | PM, Architect, Engineer, Reviewer | a change should go all the way to reviewed code | `spec.md`, `plan.md`, commits, review verdict |
| `product-design` | PM, Engineer, Architect | a feature needs a spec | `spec.md` |
| `design-debate` | Advocate, Skeptic, Synthesizer | a design or technology choice must be made | `adr.md` |
| `security-review` | RedTeam, BlueTeam, Compliance | a threat model and a controls review | `security-review.md` |
| `incident-investigation` | LogAnalyst, ChangeAnalyst, SRELead | a regression or incident with no known cause | `incident-report.md` |

`dw templates` lists them with their phases. Every template includes a built-in Liaison, the only member that talks to you.

## How it works

```text
 you ──chat──► Claude Code ──/dw──► dw prepare ──► Workflow tool (background)
                ▲    │                                   │  fixed phases, decided by the script
                │    │ bus_reply                         ▼
         dw watch    │            Explore ─► Debate ─► Decide ─► Spec ─► Plan ─► Execute ─► Review
     (wakes Claude   │            agent ◄──► agent ◄──► agent   (multicast, fan-in, ask/reply)
      when the team  ▼                   └── Liaison ── bus_ask ──► you
      writes to you)
          ┌──────────────────────── workflow-bus (MCP, stdio) ────────────────────────┐
          │ .dw/runs/<run>/  run.json · messages/ · cursors/ · artifacts/ · launch.json │
          └─────────────────────────────────────────────────────────────────────────────┘
```

- **The script fixes the order of phases.** It compiles the template into a saved workflow (`.claude/workflows/dw-<template>.js`) and runs one agent call per member, per round or per work item.
- **Inside a phase, the agents converse on the bus.** The bus is a lock-free file store with per-agent cursors, so no message is lost or read twice.
- **Phases come in eight kinds**, combined freely in templates:

| Kind | What happens |
|------|--------------|
| `explore` | each member forms a position and shares it |
| `task` | each member does its part and reports findings |
| `debate` | rounds of stances and critiques until consensus |
| `escalate` | blocking questions go to you in one batch |
| `synthesize` | an owner writes a document, reviewers approve or request changes |
| `plan` | like `synthesize`, and also returns ordered work items with acceptance criteria |
| `execute` | each work item by a fresh agent, in your repository, in dependency order |
| `review` | reviewers check the delivered work; the owner fixes or rebuts, until approval |

Only the work and fix steps of `execute` and `review` may change files. Every other step is read-only.

## Commands

| Command | What it does |
|---------|--------------|
| `dw templates`, `dw validate` | list and check templates |
| `dw prepare <template> --brief "…" [--artifact name=path]` | compile, open a run, print the launch data (`/dw` does this for you) |
| `dw tail <run> [--follow]`, `dw status [<run>]` | follow and inspect runs |
| `dw inbox`, `dw reply <run> <seq> <answer>` | read and answer what the team sent you |
| `dw export <run>` | write the transcript to Markdown |
| `dw doctor [--json]` | check the setup of the current project |
| `dw setup` | install `/dw` for every project (the installer runs it) |
| `dw init` | wire only the current project (`.mcp.json`, `/dw`, `.gitignore`) |

## Customize

Put your own templates in `<project>/.claude/dw-templates/{agents,workflows}/`. A template there replaces a packaged one with the same `id`. Check them with `dw validate`.

```json
{
  "id": "engineer",
  "name": "Senior Engineer",
  "summary": "Grounds the discussion in implementation reality.",
  "perspective": "Feasibility, risk, effort and how it will be tested.",
  "mission": "Make sure what the team agrees on can be built and tested.",
  "skills": [
    { "name": "superpowers:test-driven-development", "phases": ["execute"], "how": "Write the failing test first." }
  ],
  "rules": ["Never call something easy without pointing at code."],
  "context": { "L1": ["artifact:spec.md"] }
}
```

The fields of agent and workflow templates, and the context keys, are listed in `templates/README.md` inside the package (`~/.cdw/app/templates/README.md`).

## Safety

- **`feature-delivery` changes your repository.** It commits each work item on the branch you are on, and stages only the files it changed. It never pushes, merges, rebases, amends, resets or switches branches. Your own uncommitted changes are left alone.
- **Agents run with your permission mode.** Background agents need permission to edit files and run commands. If every action needs a confirmation, they cannot proceed.
- **Every agent call is a subagent, so runs cost tokens.** A `product-design` run uses about 10 to 20 agent calls. A `feature-delivery` run with six work items uses about 20 to 35.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `/dw` is unknown | restart Claude Code after installing |
| no `Workflow` tool | enable **Dynamic workflows** in `/config` |
| `workflow-bus` tools missing | `/mcp` and reconnect `workflow-bus`; `claude mcp list` should show it |
| anything else | `dw doctor` in the project (`dw doctor --json` for scripts and CI) |
