#!/usr/bin/env bash
# Usage: eval-configs.sh [extra nix eval flags...] < matrix.json
#
# Evaluates (doesn't build) every configuration in a build-matrix.sh matrix.
# Prints each distinct evaluation warning once, followed by the
# configurations that emit it; prints nothing when there are none. Exits 1,
# with the errors on stderr, if any configuration fails to evaluate: `nix
# flake check` doesn't evaluate homeConfigurations, so this is what catches
# those.
#
# Warnings span several lines when the message does (continuation lines are
# indented), so a block runs from the "evaluation warning:" line through the
# indented lines after it. "trace: warning:" is the older lib.warn format.
# Store paths of flake sources are stripped so a warning reads the same, and
# compares equal, from one commit to the next.
set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failed=()

while read -r row; do
  name=$(jq -r .name <<<"$row")
  installable=$(jq -r .installable <<<"$row")
  echo "### $name" >>"$tmp/all"
  if ! nix eval "$@" --raw "$installable.drvPath" 2>"$tmp/err" >/dev/null; then
    failed+=("$name")
    {
      echo "--- $name failed to evaluate:"
      cat "$tmp/err"
    } >&2
  fi
  cat "$tmp/err" >>"$tmp/all"
done < <(jq -c '.include[]')

awk '
  function flush() {
    if (cur != "") {
      if (!(cur in hosts)) order[++n] = cur
      hosts[cur] = hosts[cur] (hosts[cur] != "" ? ", " : "") name
      cur = ""
    }
  }
  /^### / { flush(); name = substr($0, 5); next }
  /^(evaluation warning|trace: warning):/ { flush(); cur = $0; next }
  cur != "" && /^[ \t]/ { cur = cur "\n" $0; next }
  { flush() }
  END {
    flush()
    for (i = 1; i <= n; i++) printf "%s\n  in: %s\n\n", order[i], hosts[order[i]]
  }
' "$tmp/all" | sed -E 's#/nix/store/[0-9a-z]{32}-source/##g'

if [ ${#failed[@]} -gt 0 ]; then
  echo "Failed to evaluate: ${failed[*]}" >&2
  exit 1
fi
