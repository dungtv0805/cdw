# Installing cdw

## Requirements

- macOS or Linux (on Windows, use WSL)
- Node.js 20 or newer, with npm
- Claude Code, with **Dynamic workflows** enabled in `/config` (without it Claude Code has no `Workflow` tool)
- `curl` and `tar` for the one-line installer

## One-line install (recommended)

```bash
# every project on this machine (user scope, the default)
curl -fsSL https://raw.githubusercontent.com/dungtv0805/cdw/main/install.sh | bash

# only the project you are in (project scope)
curl -fsSL https://raw.githubusercontent.com/dungtv0805/cdw/main/install.sh | bash -s -- --scope project

# only the dw CLI, wire projects later with dw setup or dw init
curl -fsSL https://raw.githubusercontent.com/dungtv0805/cdw/main/install.sh | bash -s -- --scope none
```

Every scope installs the package into `~/.cdw/app` (runtime dependencies only) and links `dw` and `dw-bus` into `~/.local/bin`. What happens next depends on the scope:

- **`user`:**
  - `dw setup` writes `/dw` and `/dw-inbox` into `~/.claude/commands/` (or `$CLAUDE_CONFIG_DIR/commands/`).
  - The installer registers the MCP server: `claude mcp add-json workflow-bus "$(dw setup --mcp-json)" --scope user`.
  - The server has no fixed store, so every project keeps its runs in its own `.dw/`.
- **`project`:** `dw init` runs in the current directory and writes, in that directory:
  - `.mcp.json`, with the `workflow-bus` server pinned to `./.dw`;
  - `.claude/commands/dw.md` and `.claude/commands/dw-inbox.md`;
  - `.gitignore` entries for `.dw/` and the generated workflow scripts;
  - the saved workflows, in `.claude/workflows/`.

  These files hold absolute paths of this machine (the installed `dw-bus`, the project's store), so do not commit them. Each teammate runs the installer. If your `.mcp.json` is already committed, prefer the user scope.
- **`none`:** nothing beyond the CLI.

A project's `.mcp.json` takes precedence over the user-scope server, so the two scopes can coexist.

Options, as environment variables placed before `bash`:

| Variable | Default | Meaning |
|----------|---------|---------|
| `CDW_SCOPE` | `user` | `user`, `project` or `none` (`--scope` wins) |
| `CDW_HOME` | `~/.cdw` | install directory |
| `CDW_BIN_DIR` | `~/.local/bin` | where `dw` and `dw-bus` are linked |
| `CDW_REF` | `main` | branch or tag to install |
| `CDW_REPO` | `dungtv0805/cdw` | GitHub repository to install from |
| `CDW_ARCHIVE` | the GitHub archive of `CDW_REPO` at `CDW_REF` | a `.tar.gz` URL or a local file, for offline installs |

Then restart Claude Code (or reconnect `workflow-bus` with `/mcp`).

## From a tarball

Build or download `claude-dynamic-workflow-<version>.tgz`, then:

```bash
npm install -g claude-dynamic-workflow-<version>.tgz

# every project:
dw setup
claude mcp add-json workflow-bus "$(dw setup --mcp-json)" --scope user

# or one project, from inside it:
dw init
```

## Verify

```bash
dw --help
cd your-project && dw doctor       # dw doctor --json for scripts and CI
```

`dw doctor` checks four things:
- `workflow-bus` is registered, for this project or for every project;
- the project's store (`.dw`) exists or can be created on the first run;
- the templates load;
- the bus store works.

## Update and uninstall

- **Update:** run the install command again. It replaces `~/.cdw/app` and keeps your projects' `.dw/` folders.
- **Uninstall:**

  ```bash
  curl -fsSL https://raw.githubusercontent.com/dungtv0805/cdw/main/install.sh | bash -s -- --uninstall
  ```

  It removes `~/.cdw/app`, the `dw` and `dw-bus` links, the user-level `/dw` commands, and the user-scope MCP server. It does not touch any project: delete a project's `.dw/`, its generated `.claude/workflows/dw-*.js` and its `workflow-bus` entry in `.mcp.json` yourself if you want them gone.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `dw: command not found` | add `~/.local/bin` to `PATH`: `export PATH="$HOME/.local/bin:$PATH"` (fish: `fish_add_path ~/.local/bin`) |
| `/dw` is not offered in Claude Code | restart Claude Code; check `~/.claude/commands/dw.md` (user scope) or `.claude/commands/dw.md` (project scope) |
| no `Workflow` tool | enable **Dynamic workflows** in `/config` |
| `workflow-bus` tools missing | `claude mcp list` should list it; reconnect it with `/mcp`; re-register with the command `dw setup` prints |
| `dw doctor` reports a problem | follow the `Fix:` line under the failed check |
| agents stop at permission prompts | background agents need permission to edit files and run commands; use a permission mode that allows them |

## Building from source (maintainers)

```bash
npm ci
npm run release          # typecheck, lint, test, then npm pack (prepack builds the minified dist)
npm run smoke            # installs the tarball into a temporary prefix and exercises dw and dw-bus
npm run export -- ~/code/cdw   # the distribution repository the installer downloads
```
