#!/usr/bin/env bash
# Usage: eval-warnings.sh [extra nix eval flags...] < matrix.json
#
# Evaluates (doesn't build) every configuration in the flake-update build
# matrix and prints each distinct evaluation warning once, followed by the
# configurations that emit it. Prints nothing when there are none.
#
# Warnings span several lines when the message does (continuation lines are
# indented), so a block runs from the "evaluation warning:" line through the
# indented lines after it. "trace: warning:" is the older lib.warn format.
set -euo pipefail

jq -c '.include[]' | while read -r row; do
  name=$(jq -r .name <<<"$row")
  installable=$(jq -r .installable <<<"$row")
  echo "### $name"
  # stderr only; a failed eval is the build job's problem, not ours.
  nix eval "$@" --raw "$installable.drvPath" 2>&1 >/dev/null || true
done | awk '
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
'
