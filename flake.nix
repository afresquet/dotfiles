{
  description = "My NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    stylix.url = "github:danth/stylix";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      home-manager,
      ...
    }@inputs:
    let
      inherit (self) outputs;

      forEachSystem = nixpkgs.lib.genAttrs (import systems);

      utils = import ./utils.nix { inherit (nixpkgs) lib; };

      libAndUtils = {
        inherit (nixpkgs) lib;
        inherit utils;
      };

      nixosSystem =
        system: module:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs outputs;
          };
          modules = [ module ];
        };

      homeManagerConfiguration =
        { module, pkgs }:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs outputs;
          };
          modules = [ module ];
        };
    in
    {
      packages = forEachSystem (
        system: import ./pkgs (libAndUtils // { pkgs = nixpkgs.legacyPackages.${system}; })
      );

      formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      overlays = import ./overlays libAndUtils;

      nixosModules = import ./modules/nixos libAndUtils;

      homeManagerModules = import ./modules/home-manager libAndUtils;

      nixosConfigurations = {
        Alvaro-Desktop = nixosSystem "x86_64-linux" ./hosts/desktop/configuration.nix;

        Alvaro-Laptop = nixosSystem "x86_64-linux" ./hosts/laptop/configuration.nix;
      };

      homeConfigurations = {
        "afresquet@Alvaro-Desktop" = homeManagerConfiguration {
          module = ./hosts/desktop/home.nix;
          inherit (outputs.nixosConfigurations.Alvaro-Desktop) pkgs;
        };

        "afresquet@Alvaro-Laptop" = homeManagerConfiguration {
          module = ./hosts/laptop/home.nix;

          inherit (outputs.nixosConfigurations.Alvaro-Laptop) pkgs;
        };

        "afresquet@mac-afresquet" = homeManagerConfiguration {
          module = ./hosts/work/home.nix;

          pkgs = import nixpkgs {
            system = "x86_64-darwin";

            overlays = [
              outputs.overlays.additions
              outputs.overlays.modifications
            ];
          };
        };
      };
    };
}
