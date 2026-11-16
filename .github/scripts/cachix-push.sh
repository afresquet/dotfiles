#!/usr/bin/env bash
# Usage: cachix-push.sh [--dry-run] <cache> <store path>
#
# Pushes the closure of <store path> to the Cachix cache <cache>, leaving out
# every path that cache.nixos.org or another substituter of setup-nix's
# `extra-substituters` already serves: hosts download those from there, and
# copies of the Pi's kernel and firmware (nixos-raspberrypi) or of
# nix-community's packages would otherwise fill the free plan's 5 GB. The
# substituters are read from the action so the two can't drift apart; every
# one of them must also be in the Pi's nix.settings.substituters, or it can't
# substitute what this leaves out.
#
# `cachix push` always pushes a whole closure, leaving out only what the
# cache itself or cache.nixos.org has, so the filtered paths go through
# `.#cachix-omit-deps` (pkgs/cachix-omit-deps) one by one. Needs
# CACHIX_AUTH_TOKEN, except with --dry-run, which prints the paths it would
# push instead.
set -euo pipefail

dry_run=false
if [ "${1:-}" = --dry-run ]; then
  dry_run=true
  shift
fi
cache=$1 out=$2

action=$(dirname "$0")/../actions/setup-nix/action.yml
read -ra substituters < <(sed -n 's/^ *extra-substituters = //p' "$action")
if [ ${#substituters[@]} -eq 0 ]; then
  echo "no extra-substituters in $action" >&2
  exit 1
fi

# "<path> <nar size>" per line.
closure=$(nix path-info --recursive --size "$out" | awk '{ print $1, $2 }')
missing=$(cut -d' ' -f1 <<<"$closure")
for url in https://cache.nixos.org "${substituters[@]}"; do
  [ "$url" = "https://$cache.cachix.org" ] && continue
  before=$(grep -c . <<<"$missing" || true)
  missing=$(xargs -r nix-store --store "$url" --check-validity --print-invalid <<<"$missing")
  echo "$url: $((before - $(grep -c . <<<"$missing" || true))) paths"
done

awk '
  NR == FNR { if ($1 != "") push[$1]; next }
  $1 in push { n++; size += $2; next }
  { skipped++; skippedSize += $2 }
  END {
    printf "Skipping %d paths (%d MB) other caches serve, pushing %d (%d MB)\n",
      skipped, skippedSize / 1e6, n, size / 1e6
  }
' <(printf '%s\n' "$missing") <(printf '%s\n' "$closure")

if [ -z "$missing" ]; then
  exit 0
elif $dry_run; then
  printf '%s\n' "$missing"
else
  printf '%s\n' "$missing" | nix run .#cachix-omit-deps -- push --omit-deps "$cache"
fi
