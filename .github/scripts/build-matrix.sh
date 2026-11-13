#!/usr/bin/env bash
# Usage: build-matrix.sh [extra nix eval flags...]
#
# Prints the GitHub Actions matrix of every NixOS, nix-darwin and
# home-manager configuration in the flake, derived from the flake itself so
# new hosts are picked up without touching the workflows. Each configuration
# builds on a runner of its own platform, one per job so a desktop closure
# gets the whole runner disk to itself.
set -euo pipefail

systems='cs: builtins.mapAttrs (_: c: c.pkgs.stdenv.hostPlatform.system) cs'
jq -cn \
  --argjson nixos "$(nix eval "$@" --json .#nixosConfigurations --apply "$systems")" \
  --argjson darwin "$(nix eval "$@" --json .#darwinConfigurations --apply "$systems")" \
  --argjson home "$(nix eval "$@" --json .#homeConfigurations --apply "$systems")" \
  '
  def runner:
    { "x86_64-linux": "ubuntu-24.04",
      "aarch64-linux": "ubuntu-24.04-arm",
      "aarch64-darwin": "macos-latest" }[.]
    // error("no runner for \(.)");
  def entries($kind; $attr):
    to_entries | map({
      name: "\($kind) \(.key)",
      runner: (.value | runner),
      # Only the Pi is too slow to compile; pushing everything would churn
      # through the free Cachix quota every week.
      push: (.value == "aarch64-linux"),
      installable: ".#\($kind)Configurations.\"\(.key)\".\($attr)"
    });
  { include:
      (($nixos | entries("nixos"; "config.system.build.toplevel"))
    + ($darwin | entries("darwin"; "config.system.build.toplevel"))
    + ($home | entries("home"; "activationPackage"))) }
  '
