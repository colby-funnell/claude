#!/usr/bin/env bash
# Log each tool invocation (tool name, input, cwd) as one JSONL line to a daily
# file, so we can later mine recurring commands for MCP-tool candidates.
# Best-effort: must never fail or block the tool call that triggered it.
log_dir="$HOME/.claude/command-logs"
mkdir -p "$log_dir" 2>/dev/null || exit 0
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
day="$(date -u +%F)"
jq -c --arg ts "$ts" --arg pwd "$PWD" \
  '{ts: $ts, cwd: (.cwd // $pwd), tool: .tool_name, input: .tool_input}' \
  >> "$log_dir/$day.jsonl" 2>/dev/null || true
