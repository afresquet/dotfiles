#!/usr/bin/env bash
# Usage: build-matrix.sh [--changed-since REV] [extra nix eval flags...]
#
# Prints the GitHub Actions matrix of every NixOS, nix-darwin and
# home-manager configuration in the flake, derived from the flake itself so
# new hosts are picked up without touching the workflows. Each configuration
# builds on a runner of its own platform, one per job so a desktop closure
# gets the whole runner disk to itself.
#
# Each entry also carries `substituters`, the binary caches the target
# machine itself downloads from, for cachix-push.sh to leave out what they
# already serve. A home configuration "user@host" takes its host's: standalone
# home-manager substitutes through that host's daemon.
#
# With --changed-since, only the configurations whose derivation differs
# between the working tree and REV are listed (an empty `include` when none
# does), so a change that doesn't alter what a machine runs builds nothing.
# A configuration REV doesn't have, or a REV that fails to evaluate, counts
# as changed.
set -euo pipefail

base=""
if [ "${1:-}" = --changed-since ]; then
  base=$2
  shift 2
fi

# name -> system for every configuration of one kind.
systems='cs: builtins.mapAttrs (_: c: c.pkgs.stdenv.hostPlatform.system) cs'
# name -> substituters of every system configuration of one kind, as the
# machine's daemon sees them. NixOS lists cache.nixos.org in `substituters`
# by default; Determinate Nix (both Macs) keeps it built in and only takes
# `extra-substituters` from customSettings.
nixosSubstituters='cs: builtins.mapAttrs (_: c: let s = c.config.nix.settings; in
  (s.substituters or [ ]) ++ (s.extra-substituters or [ ])) cs'
darwinSubstituters='cs: builtins.mapAttrs (_: c: let s = c.config.determinateNix.customSettings; in
  (s.substituters or [ "https://cache.nixos.org" ]) ++ (s.extra-substituters or [ ])) cs'
# Usage: drvs FLAKE KIND [nix eval flags...]; prints name -> drvPath for
# every configuration of that kind.
drvs() {
  local attr
  case $2 in
    home) attr=activationPackage ;;
    *) attr=config.system.build.toplevel ;;
  esac
  nix eval "${@:3}" --json "$1#$2Configurations" \
    --apply "cs: builtins.mapAttrs (_: c: c.$attr.drvPath) cs"
}

matrix=$(jq -cn \
  --argjson nixos "$(nix eval "$@" --json .#nixosConfigurations --apply "$systems")" \
  --argjson darwin "$(nix eval "$@" --json .#darwinConfigurations --apply "$systems")" \
  --argjson home "$(nix eval "$@" --json .#homeConfigurations --apply "$systems")" \
  --argjson nixosSubst "$(nix eval "$@" --json .#nixosConfigurations --apply "$nixosSubstituters")" \
  --argjson darwinSubst "$(nix eval "$@" --json .#darwinConfigurations --apply "$darwinSubstituters")" \
  '
  def runner:
    { "x86_64-linux": "ubuntu-24.04",
      "aarch64-linux": "ubuntu-24.04-arm",
      "aarch64-darwin": "macos-latest" }[.]
    // error("no runner for \(.)");
  # By system configuration name, without trailing slashes or duplicates. A
  # home configuration whose host is not in the flake gets cache.nixos.org
  # alone, so everything else in its closure is pushed.
  def substituters($kind; $config):
    ($nixosSubst + $darwinSubst | map_values(map(rtrimstr("/")) | unique)) as $subst
    | if $kind == "home"
      then $subst[$config | split("@")[1]] // ["https://cache.nixos.org"]
      else $subst[$config] end;
  def entries($kind; $attr):
    to_entries | map({
      name: "\($kind) \(.key)",
      kind: $kind,
      config: .key,
      runner: (.value | runner),
      installable: ".#\($kind)Configurations.\"\(.key)\".\($attr)",
      substituters: substituters($kind; .key)
    });
  { include:
      (($nixos | entries("nixos"; "config.system.build.toplevel"))
    + ($darwin | entries("darwin"; "config.system.build.toplevel"))
    + ($home | entries("home"; "activationPackage"))) }
  ')

if [ -z "$base" ]; then
  echo "$matrix"
  exit 0
fi

tmp=$(mktemp -d)
cleanup() {
  git worktree remove --force "$tmp/base" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

# Missing or failing at REV: every configuration of that kind counts as
# changed (an empty set never matches HEAD's drvPath).
old='{}'
new='{}'
if git worktree add --quiet --detach "$tmp/base" "$base" >&2; then
  for kind in nixos darwin home; do
    o=$(drvs "$tmp/base" "$kind" "$@") || o='{}'
    n=$(drvs . "$kind" "$@")
    old=$(jq -c --arg k "$kind" --argjson v "$o" '. + {($k): $v}' <<<"$old")
    new=$(jq -c --arg k "$kind" --argjson v "$n" '. + {($k): $v}' <<<"$new")
  done
else
  echo "build-matrix: can't check out $base, listing everything" >&2
fi

jq -c --argjson old "$old" --argjson new "$new" '
  .include |= map(select($old[.kind][.config] == null
    or $old[.kind][.config] != $new[.kind][.config]))
' <<<"$matrix"
