{
  description = "NixOS, nix-darwin and home-manager configurations for all my machines";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:nixos/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Deliberately not following nixpkgs: it pins the stable release its
    # binary cache is built against, and the Pi can't afford to build.
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    # Deliberately not following nixpkgs so the hyprland.cachix.org binaries
    # match.
    hyprland.url = "github:hyprwm/Hyprland";
    stylix = {
      url = "github:nix-community/stylix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
    hunk = {
      url = "github:modem-dev/hunk";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    # Imports every .nix file under modules/ as a flake-parts module.
    import-tree.url = "github:vic/import-tree";
    # AI agent skill sources (not flakes).
    tilth = {
      url = "github:jahala/tilth";
      flake = false;
    };
  };

  # Every .nix file under modules/ is a flake-parts module (import-tree skips
  # paths with a `_`-prefixed component). See AGENTS.md for the layout.
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
