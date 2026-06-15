#!/usr/bin/env bash
# Symlink versioned Claude config from this repo into ~/.claude/.
# Idempotent: re-running is safe. Existing files/symlinks that don't already
# point at this repo are moved aside to ~/.claude/<name>.pre-link.<timestamp>.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
TS="$(date +%Y%m%d-%H%M%S)"

mkdir -p "${CLAUDE_DIR}"

# Top-level entries to link from repo root → ~/.claude/<name>.
# Add new versioned paths here (e.g. "commands").
ENTRIES=(
  "CLAUDE.md"
  "settings.json"
  "agents"
)

link_one() {
  local name="$1"
  local src="${REPO_DIR}/${name}"
  local dst="${CLAUDE_DIR}/${name}"

  if [[ ! -e "${src}" ]]; then
    echo "skip: ${name} (not in repo)"
    return
  fi

  if [[ -L "${dst}" ]]; then
    local current
    current="$(readlink "${dst}")"
    if [[ "${current}" == "${src}" ]]; then
      echo "ok:   ${dst} → ${src}"
      return
    fi
    echo "move: ${dst} (was symlink → ${current}) → ${dst}.pre-link.${TS}"
    mv "${dst}" "${dst}.pre-link.${TS}"
  elif [[ -e "${dst}" ]]; then
    echo "move: ${dst} → ${dst}.pre-link.${TS}"
    mv "${dst}" "${dst}.pre-link.${TS}"
  fi

  ln -s "${src}" "${dst}"
  echo "link: ${dst} → ${src}"
}

for entry in "${ENTRIES[@]}"; do
  link_one "${entry}"
done

echo "done."
