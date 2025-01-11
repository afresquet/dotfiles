{
  description = "My NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      nix-darwin,
      systems,
      home-manager,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      inherit (nixpkgs) lib;

      forEachSystem = lib.genAttrs (import systems);

      utils = import ./utils.nix { inherit lib; };

      libAndUtils = {
        inherit lib utils;
      };

      nixosSystem =
        { system, module }:
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
        Alvaro-Desktop = nixosSystem {
          system = "x86_64-linux";

          module = ./hosts/desktop/configuration.nix;
        };

        Alvaro-Laptop = nixosSystem {
          system = "x86_64-linux";

          module = ./hosts/laptop/configuration.nix;
        };
      };

      darwinConfigurations = {
        Alvaros-Mac-mini = nix-darwin.lib.darwinSystem {
          modules = [ ./hosts/mac-mini/configuration.nix ];
        };
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

        "afresquet@Alvaros-Mac-mini" = homeManagerConfiguration {
          module = ./hosts/mac-mini/home.nix;

          pkgs = import nixpkgs {
            system = "aarch64-darwin";

            overlays = [
              outputs.overlays.additions
              outputs.overlays.modifications
            ];
          };
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
