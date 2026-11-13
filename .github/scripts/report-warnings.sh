#!/usr/bin/env bash
# Usage: report-warnings.sh < warnings   (eval-configs.sh output for main)
#
# Keeps the "Evaluation warnings" issue in sync with main. A new or changed
# set of warnings comments on the issue (or opens it) and messages Telegram;
# the same set as last reported does nothing, so pushes while a warning is
# open stay quiet; no warnings closes the issue. Each report carries a hash
# of the warnings to compare against. Needs RUN_URL plus notify.sh's
# environment.
set -euo pipefail

title="Evaluation warnings"
notify="$(dirname "$0")/notify.sh"
warnings=$(cat)
n=$("$notify" find "$title")

if [ -z "$warnings" ]; then
  echo "No evaluation warnings"
  if [ -n "$n" ]; then
    "$notify" close "$title" "No evaluation warnings as of $RUN_URL"
  fi
  exit 0
fi

hash=$(printf '%s' "$warnings" | sha256sum | cut -d' ' -f1)
if [ -n "$n" ]; then
  last=$(gh issue view "$n" --json body,comments --jq '([.body] + [.comments[].body]) | last' |
    grep -oE 'warnings-hash: [0-9a-f]{64}' | cut -d' ' -f2 || true)
  if [ "$last" = "$hash" ]; then
    echo "Warnings unchanged since the last report on #$n"
    exit 0
  fi
fi

fence='```'
printf 'Run: %s\n\nEvaluation warnings on main:\n\n%s\n%s\n%s\n\n<!-- warnings-hash: %s -->\n' \
  "$RUN_URL" "$fence" "$warnings" "$fence" "$hash" | "$notify" issue "$title"
"$notify" telegram "$(printf '⚠️ Evaluation warnings on %s main: %s\n\n%s' "$GH_REPO" "$RUN_URL" "$warnings")"
