# cdw: multi-agent teams for Claude Code

**AI agents that talk to each other, debate and deliver: a Claude Code plugin for multi-agent collaboration.**

cdw turns Claude Code into a team. Plain subagents work alone and never see each other. With cdw you get role agents instead: a PM, an Architect, an Engineer, a Reviewer, a red team, an SRE and others. They message each other live over a shared MCP message bus, argue until they agree, and bring you only the questions that really need you. One command takes a request from spec to plan to reviewed, committed code.

It runs as a background *dynamic workflow* inside Claude Code. No API key and no SDK: every agent is Claude Code itself, with your skills, your tools and your permissions.

```text
/cdw:dw feature-delivery Add a --json flag to the doctor command
```

From that one line:
- PM, Architect and Engineer explore the request and align on scope and approach.
- The PM writes `spec.md`, and the Architect and Engineer approve it.
- The Architect splits the work into small items in `plan.md`.
- The Engineer implements and commits each item, test first.
- An independent Reviewer checks the delivered commits until it approves.

You get the spec, the plan, the commits and the review verdict. Nothing is pushed.

## What people use cdw for

| You want to… | Run |
|--------------|-----|
| let several AI agents talk to each other and solve a task together | `/cdw:dw <template> <request>` |
| go from a feature request to reviewed, committed code (PM → Architect → Engineer → Reviewer) | `/cdw:dw feature-delivery …` |
| make a small, clear change quickly: a short cross-examination, at most three items, one review | `/cdw:dw quick-delivery …` |
| fix a bug test first: reproduce it, agree the root cause, then a failing test and the fix | `/cdw:dw bugfix …` |
| have three independent reviewers (rules, design, tests) review a branch before it is merged | `/cdw:dw code-review …` |
| write a product spec with a PM, an engineer and an architect who challenge each other | `/cdw:dw product-design …` |
| have agents debate a technical decision and record it as an ADR | `/cdw:dw design-debate …` |
| run a security review or threat model with red-team and blue-team agents | `/cdw:dw security-review …` |
| investigate an incident or a regression with agents working in parallel | `/cdw:dw incident-investigation …` |
| keep a human in the loop without babysitting: answer only the blocking questions | built in: the Liaison asks you once, with options |
| build your own agent team for any domain | JSON templates, see [Customize](#customize) |

## Highlights

- **A real team conversation.** Agents message one peer, several, everyone (`*`), a group (`@builders`) or a topic (`#decisions`). They wait until every peer has spoken (fan-in), and they ask and get replies, all over the `workflow-bus` MCP server.
- **Debate until consensus.** Rounds stop as soon as every member agrees. Disagreements that remain blocking become questions for you.
- **One batch of questions, with options.** A Liaison collects blocking questions and sends them to you in one message. Each question comes with options, trade-offs and the team's recommendation. Unanswered questions fall back to the recommendation.
- **End-to-end delivery.** `plan` turns a document into ordered work items, `execute` gives each item a fresh agent that works in your repository, and `review` loops reviewer checks and owner fixes until approval.
- **Templates are JSON.** An agent template is a role: its skills per phase, how it works, its rules, and its context by level. A workflow template is a request type: its team, its phases and when to escalate. Override them per project.
- **Your skills, per phase.** Agents load the Claude Code skills each template names, for example `superpowers:test-driven-development` while implementing. A skill that is not installed is applied from its description instead.
- **Observable.** Follow a run live with `dw tail <run> --follow`, inspect it with `dw status`, and export the transcript with `dw export`.

## Install

Requirements:
- macOS or Linux (on Windows, use WSL);
- Node.js 20 or newer;
- Claude Code, with **Dynamic workflows** enabled in `/config`.

### As a Claude Code plugin (recommended)

In Claude Code:

```text
/plugin marketplace add dungtv0805/cdw
/plugin install cdw@cdw
```

Or from your shell, choosing the scope:

```bash
# every project on this machine (user scope, the default)
claude plugin install cdw --marketplace dungtv0805/cdw --scope user

# this repository only, declared in .claude/settings.json: commit it and teammates are offered the plugin
claude plugin marketplace add dungtv0805/cdw --scope project
claude plugin install cdw@cdw --scope project
```

Run `/reload-plugins` (or restart Claude Code), then use:
- `/cdw:dw <template> <what you want>` to run a workflow;
- `/cdw:dw-inbox` to answer what teams sent you.

The plugin carries everything it needs: the `workflow-bus` MCP server, the commands, the saved workflows and the bundled programs. It needs no npm install, no PATH change and no absolute paths, so a project-scope install is safe to commit.

### With the install script

The script also puts the `dw` CLI on your `PATH`.

```bash
# every project (user scope, the default)
curl -fsSL https://raw.githubusercontent.com/dungtv0805/cdw/main/install.sh | bash

# only the project you are in (project scope): run it inside the project
curl -fsSL https://raw.githubusercontent.com/dungtv0805/cdw/main/install.sh | bash -s -- --scope project
```

Both scopes install cdw into `~/.cdw/app` and link `dw` and `dw-bus` into `~/.local/bin`. Then:

| Scope | `/dw` commands | `workflow-bus` MCP server | Best for |
|-------|----------------|---------------------------|----------|
| `user` (default) | `~/.claude/commands/` | registered for every project (`claude mcp add-json … --scope user`) | using cdw everywhere on your machine |
| `project` | `<project>/.claude/commands/` | `<project>/.mcp.json`, plus `.gitignore` entries and the saved workflows | one repository on this machine (the files hold this machine's paths: each teammate runs the installer) |
| `none` | not installed | not registered | only the `dw` CLI; run `dw setup` or `dw init` later |

Here the commands are `/dw` and `/dw-inbox`. Each project keeps its runs in its own `.dw/`. Restart Claude Code after installing.

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

Use one method per machine. Both work side by side, but you would get two sets of commands (`/cdw:dw` and `/dw`) and two bus servers sharing each project's `.dw/`.

### What is in this repository

```text
.claude-plugin/   plugin.json and marketplace.json (the plugin is its own marketplace)
commands/         dw.md and dw-inbox.md: the /cdw:dw and /cdw:dw-inbox commands
workflows/        saved workflows, one per template: /cdw:dw-feature-delivery, /cdw:dw-product-design, …
.mcp.json         the workflow-bus MCP server (${CLAUDE_PLUGIN_ROOT}/dist/bus/main.js)
bin/, dist/       the dw and dw-bus programs: bundled, minified, no dependencies to install
templates/        the workflow and agent templates (JSON) every command and workflow is built from
install.sh        the install script
```

The saved workflows in `workflows/` also run on their own: `/cdw:dw-feature-delivery <brief>`. Started that way, a run is **unattended**: nobody is watching for questions, so the team decides each blocking question by its recommendation and reports it as an assumed decision. Use `/cdw:dw` when you want to answer such questions yourself.

## Quick start

1. Open any project in Claude Code.
2. Run a workflow: `/cdw:dw <template> <what you want>` (`/dw` with the install script). For example: `/cdw:dw feature-delivery Add rate limiting to the login endpoint`.
3. If the team needs a decision, Claude shows you the question with its options. Answer in the chat, for example `1: a`.
4. Follow along from another terminal: `dw tail <run> --follow`.
5. Find the results:
   - documents in `.dw/runs/<run>/artifacts/`;
   - for `feature-delivery`, the commits on your current branch;
   - a summary from Claude when the run ends.

To start from a document you already have, for example a spec, say where it is: `/cdw:dw feature-delivery Implement the spec at /abs/path/spec.md`. The file is handed to the team, and the phase that would write it is skipped.

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

The `dw` CLI is on your `PATH` with the install script. With the plugin, it lives at `<plugin directory>/bin/dw`: the commands `/cdw:dw` prints, such as `tail`, use the full path.

| Command | What it does |
|---------|--------------|
| `dw templates`, `dw validate` | list and check templates |
| `dw prepare <template> --brief "…" [--artifact name=path]` | compile, open a run, print the launch data (`/cdw:dw` and `/dw` do this for you) |
| `dw tail <run> [--follow]`, `dw status [<run>]` | follow and inspect runs |
| `dw inbox`, `dw reply <run> <seq> <answer>` | read and answer what the team sent you |
| `dw export <run>` | write the transcript to Markdown |
| `dw doctor [--json] [--context]` | check the setup of the current project; `--context` checks `.claude/context/` health |
| `dw setup` | install `/dw` for every project (the installer runs it) |
| `dw init [--scaffold]` | wire only the current project; `--scaffold` generates draft context files |

## Project context scaffolding

When adopting cdw in a new project, `dw init --scaffold` generates draft `.claude/context/*.md` files so agents understand your codebase from the start.

```bash
dw init --scaffold
```

This creates `.claude/context/` with:

| File | When generated | Content |
|------|----------------|---------|
| `architecture.md` | Always | Project structure, key directories, detected patterns |
| `conventions.md` | Config files detected | Detected linting/formatting config (ESLint, Prettier, Biome, etc.) |
| `testing.md` | Complex test setup | Test frameworks, e2e patterns (only for projects with e2e + unit) |
| `api-conventions.md` | API framework detected | Endpoint patterns, auth hints |
| `domain.md` | README has content | Business glossary extracted from docs |

Each file uses confidence tiers:
- **HIGH** — written as-is, based on clear detection (e.g., `jest` in `package.json`)
- **MEDIUM** — written with `<!-- TODO: verify ... -->` markers for you to review
- **LOW** — file is skipped (except `architecture.md`, which always generates)

### Checking context health

After scaffolding, track your progress filling in the TODOs:

```bash
dw doctor --context
```

This reports:
- Whether `.claude/context/` exists
- How many context files you have
- How many `<!-- TODO: ... -->` markers remain

TODOs are informational: they don't fail the check. Resolve them at your own pace.

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
| `/cdw:dw` (or `/dw`) is unknown | `/reload-plugins` or restart Claude Code; `claude plugin list` should show `cdw` |
| no `Workflow` tool | enable **Dynamic workflows** in `/config` |
| `workflow-bus` tools missing | `/mcp` and reconnect `workflow-bus`; `claude mcp list` should show it |
| anything else | `dw doctor` in the project (`dw doctor --json` for scripts and CI) |

## FAQ

**How do the agents talk to each other?**
Each agent has a mailbox on `workflow-bus`, a local MCP server. An agent can:
- send to one peer, several, everyone, a group (`@builders`) or a topic (`#decisions`);
- wait until every peer it named has answered (fan-in);
- ask a question and block until the reply arrives.

Messages are files under the project's `.dw/`, so nothing is lost and every run can be replayed with `dw tail`.

**How is this different from Claude Code subagents?**
Subagents run on their own and report only to the main session. cdw agents also talk to one another while they work, so they can challenge a design, reach consensus, hand work over, and review each other.

**Is it a skill, a plugin or an MCP server?**
It is a Claude Code plugin, and it bundles all three:
- two slash commands, which Claude Code also lists as skills;
- five saved dynamic workflows;
- the `workflow-bus` MCP server.

Install it like any other plugin, or with the install script.

**Do I need an API key or the Anthropic SDK?**
No. Every agent is Claude Code itself, and runs count against your Claude Code plan or usage.

**Can I define my own agents and workflows?**
Yes. Roles and request types are JSON templates: skills per phase, rules, context, team and phases. Put yours in `.claude/dw-templates/` to add new ones or override the packaged ones.

**Will it change my code?**
Only `feature-delivery` does. It commits each work item on your current branch, and never pushes, merges or rewrites history. Every other template only reads.


## License

[MIT](LICENSE). The `dw` and `dw-bus` programs bundle third-party packages; their licenses are in `dist/THIRD_PARTY_LICENSES.md`.
