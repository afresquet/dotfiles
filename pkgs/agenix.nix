{ pkgs, inputs, ... }:
# Re-export the agenix CLI from its flake input so both NixOS and darwin hosts
# can pick it up via the local `additions` overlay (pkgs.agenix), without each
# host having to reach into `inputs.agenix.packages.<system>.default`.
inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
