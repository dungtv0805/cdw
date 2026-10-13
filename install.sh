#!/usr/bin/env bash
# cdw installer: Claude Dynamic Workflow for every project on this machine.
#
#   curl -fsSL https://raw.githubusercontent.com/dungtv0805/cdw/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/dungtv0805/cdw/main/install.sh | bash -s -- --scope project
#   curl -fsSL https://raw.githubusercontent.com/dungtv0805/cdw/main/install.sh | bash -s -- --uninstall
#
# Installs the package into ~/.cdw/app and links dw and dw-bus into ~/.local/bin, then:
#   --scope user     (default) /dw and /dw-inbox in ~/.claude/commands and the workflow-bus
#                    MCP server registered for every project (claude mcp add-json --scope user)
#   --scope project  only the current directory: dw init writes .mcp.json, .claude/commands,
#                    .gitignore entries and the saved workflows there (commit them to share)
#   --scope none     the dw CLI only
#
# Environment:
#   CDW_SCOPE    user, project or none        (default user; --scope wins)
#   CDW_REPO     GitHub repository            (default dungtv0805/cdw)
#   CDW_REF      branch or tag to install     (default main)
#   CDW_ARCHIVE  tar.gz URL or local file     (default the GitHub archive of CDW_REPO at CDW_REF)
#   CDW_HOME     install directory            (default ~/.cdw)
#   CDW_BIN_DIR  where dw and dw-bus go       (default ~/.local/bin)
set -euo pipefail

CDW_REPO="${CDW_REPO:-dungtv0805/cdw}"
CDW_REF="${CDW_REF:-main}"
CDW_ARCHIVE="${CDW_ARCHIVE:-https://codeload.github.com/${CDW_REPO}/tar.gz/${CDW_REF}}"
CDW_HOME="${CDW_HOME:-$HOME/.cdw}"
CDW_BIN_DIR="${CDW_BIN_DIR:-$HOME/.local/bin}"
CDW_SCOPE="${CDW_SCOPE:-user}"
MIN_NODE_MAJOR=20
BUS_SERVER=workflow-bus
APP="$CDW_HOME/app"
INSTALL_URL="https://raw.githubusercontent.com/${CDW_REPO}/${CDW_REF}/install.sh"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 is required: $2"; }

uninstall() {
  say "Removing cdw from $APP"
  if command -v claude >/dev/null 2>&1; then
    claude mcp remove "$BUS_SERVER" --scope user >/dev/null 2>&1 || true
  fi
  for name in dw dw-bus; do
    link="$CDW_BIN_DIR/$name"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$APP/bin/$name" ]; then
      rm -f "$link"
    fi
  done
  commands="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands"
  for name in dw.md dw-inbox.md; do
    # Only the commands this installation wrote: they call $APP/bin/dw.
    if [ -f "$commands/$name" ] && grep -q "$APP/bin/dw" "$commands/$name"; then
      rm -f "$commands/$name"
    fi
  done
  rm -rf "$APP"
  say "Done. Project files (.dw/, .claude/workflows/dw-*.js, .mcp.json entries written by dw init) were left as they are."
}

usage() { echo "usage: install.sh [--scope user|project|none] [--uninstall]"; }

action=install
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) action=uninstall ;;
    --scope) [ $# -ge 2 ] || die "--scope needs a value: user, project or none"; CDW_SCOPE="$2"; shift ;;
    --scope=*) CDW_SCOPE="${1#--scope=}" ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "unknown option $1" ;;
  esac
  shift
done
if [ "$action" = uninstall ]; then uninstall; exit 0; fi
case "$CDW_SCOPE" in
  user | none) ;;
  project)
    project_dir="$(pwd -P)"
    [ "$project_dir" != "$(cd "$HOME" && pwd -P)" ] || die "--scope project wires the current directory: run it from your project, not from \$HOME"
    ;;
  *) die "unknown scope $CDW_SCOPE: use user, project or none" ;;
esac

need node "install Node.js ${MIN_NODE_MAJOR} or newer (https://nodejs.org)"
need npm "it comes with Node.js"
need tar "install tar"
node_major="$(node -p 'process.versions.node.split(".")[0]')"
[ "$node_major" -ge "$MIN_NODE_MAJOR" ] || die "Node.js ${MIN_NODE_MAJOR}+ is required (found $(node --version))"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

say "Downloading $CDW_ARCHIVE"
case "$CDW_ARCHIVE" in
  http://* | https://*)
    need curl "install curl"
    curl -fsSL "$CDW_ARCHIVE" -o "$tmp/cdw.tar.gz" || die "download failed: $CDW_ARCHIVE"
    ;;
  *)
    [ -f "$CDW_ARCHIVE" ] || die "archive not found: $CDW_ARCHIVE"
    cp "$CDW_ARCHIVE" "$tmp/cdw.tar.gz"
    ;;
esac
mkdir "$tmp/src"
tar -xzf "$tmp/cdw.tar.gz" -C "$tmp/src"
manifest="$(find "$tmp/src" -maxdepth 2 -name package.json | head -n 1)"
[ -n "$manifest" ] || die "the archive has no package.json"
pkg="$(dirname "$manifest")"
[ -f "$pkg/dist/dw/main.js" ] && [ -f "$pkg/dist/bus/main.js" ] || die "the archive does not contain a built cdw package"
version="$(cd "$pkg" && node -p 'require("./package.json").version')"

say "Installing cdw $version into $APP"
(cd "$pkg" && npm install --omit=dev --ignore-scripts --no-audit --no-fund --no-update-notifier --loglevel=error >/dev/null) || die "npm install failed"
mkdir -p "$CDW_HOME"
rm -rf "$APP.new" "$APP.old"
mv "$pkg" "$APP.new"
if [ -d "$APP" ]; then mv "$APP" "$APP.old"; fi
mv "$APP.new" "$APP"
rm -rf "$APP.old"

mkdir -p "$CDW_BIN_DIR"
ln -sf "$APP/bin/dw" "$CDW_BIN_DIR/dw"
ln -sf "$APP/bin/dw-bus" "$CDW_BIN_DIR/dw-bus"
"$APP/bin/dw" --help >/dev/null || die "the installed dw does not start"

case "$CDW_SCOPE" in
  user)
    say "Installing /dw and /dw-inbox for every project (user scope)"
    "$APP/bin/dw" setup >/dev/null
    if command -v claude >/dev/null 2>&1; then
      claude mcp remove "$BUS_SERVER" --scope user >/dev/null 2>&1 || true
      if claude mcp add-json "$BUS_SERVER" "$("$APP/bin/dw" setup --mcp-json)" --scope user >/dev/null; then
        say "Registered the $BUS_SERVER MCP server for every project"
      else
        warn "could not register the $BUS_SERVER MCP server; run the command printed by: dw setup"
      fi
    else
      warn "claude CLI not found: register the $BUS_SERVER MCP server with the command printed by: dw setup"
    fi
    ;;
  project)
    say "Wiring $project_dir (project scope)"
    "$APP/bin/dw" --project "$project_dir" init >/dev/null
    say "Wrote .mcp.json, .claude/commands/dw*.md, .gitignore entries and the saved workflows in $project_dir"
    ;;
  none) say "Installed the dw CLI only (scope none): run dw setup or dw init when you want /dw" ;;
esac

case ":$PATH:" in
  *":$CDW_BIN_DIR:"*) ;;
  *) warn "$CDW_BIN_DIR is not on your PATH. bash/zsh: export PATH=\"$CDW_BIN_DIR:\$PATH\"   fish: fish_add_path $CDW_BIN_DIR" ;;
esac

cat <<EOF

cdw $version is installed.
  1. Restart Claude Code (or reconnect $BUS_SERVER with /mcp).
  2. Enable "Dynamic workflows" in /config.
  3. $( [ "$CDW_SCOPE" = project ] && echo "In this project" || echo "In any project"): /dw feature-delivery <what to build>   (all templates: dw templates)

Check a project with: dw doctor
Update: run the install command again.   Uninstall: curl -fsSL $INSTALL_URL | bash -s -- --uninstall
EOF
