#!/usr/bin/env bash
# Install the canonical post-commit review hook into a repo by symlink.
# Usage:
#   install.sh              # install into the current git repo
#   install.sh /path/to/repo
#
# Idempotent. Existing post-commit hooks are moved aside to
# .git/hooks/post-commit.pre-link.<timestamp>.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SRC="${SCRIPT_DIR}/post-commit"

if [[ ! -f "${HOOK_SRC}" ]]; then
  echo "fatal: canonical hook not found at ${HOOK_SRC}" >&2
  exit 1
fi

target="${1:-$(pwd)}"
target="$(cd "${target}" && pwd)"

if [[ ! -d "${target}/.git" ]]; then
  echo "fatal: ${target} is not a git repo (no .git/ dir)" >&2
  exit 1
fi

mkdir -p "${target}/.git/hooks"
dst="${target}/.git/hooks/post-commit"
ts="$(date +%Y%m%d-%H%M%S)"

if [[ -L "${dst}" ]]; then
  current="$(readlink "${dst}")"
  if [[ "${current}" == "${HOOK_SRC}" ]]; then
    echo "ok:   ${dst} → ${HOOK_SRC}"
    exit 0
  fi
  echo "move: ${dst} (was symlink → ${current}) → ${dst}.pre-link.${ts}"
  mv "${dst}" "${dst}.pre-link.${ts}"
elif [[ -e "${dst}" ]]; then
  echo "move: ${dst} → ${dst}.pre-link.${ts}"
  mv "${dst}" "${dst}.pre-link.${ts}"
fi

ln -s "${HOOK_SRC}" "${dst}"
echo "link: ${dst} → ${HOOK_SRC}"
