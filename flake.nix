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
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
        {
          system,
          module,
          builder ? nixpkgs.lib.nixosSystem,
        }:
        builder {
          inherit system;

          specialArgs = {
            inherit inputs outputs;
          };

          modules = [ module ];
        };

      homeManagerConfiguration =
        {
          module,
          pkgs,
          nixosAllowedUnfree ? [ ],
        }:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = {
            inherit inputs outputs utils;
            inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;
          };

          modules = [
            module
            { inherit nixosAllowedUnfree; }
          ];
        };
    in
    {
      packages = forEachSystem (
        system: import ./pkgs (libAndUtils // { pkgs = nixpkgs.legacyPackages.${system}; })
      );

      formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt);

      overlays = import ./overlays libAndUtils;

      nixosModules = import ./modules/nixos libAndUtils;

      darwinModules = import ./modules/darwin libAndUtils;

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

        Home-Server = nixosSystem {
          system = "aarch64-linux";

          module = ./hosts/home-server/configuration.nix;

          builder = inputs.nixos-raspberrypi.lib.nixosSystem;
        };
      };

      darwinConfigurations = {
        Alvaros-Mac-mini = nix-darwin.lib.darwinSystem {
          specialArgs = {
            inherit inputs outputs;
          };
          modules = [ ./hosts/mac-mini/configuration.nix ];
        };
      };

      homeConfigurations = {
        "afresquet@Alvaro-Desktop" = homeManagerConfiguration {
          module = ./hosts/desktop/home.nix;

          inherit (outputs.nixosConfigurations.Alvaro-Desktop) pkgs;

          nixosAllowedUnfree = outputs.nixosConfigurations.Alvaro-Desktop.config.allowedUnfree;
        };

        "afresquet@Alvaro-Laptop" = homeManagerConfiguration {
          module = ./hosts/laptop/home.nix;

          inherit (outputs.nixosConfigurations.Alvaro-Laptop) pkgs;

          nixosAllowedUnfree = outputs.nixosConfigurations.Alvaro-Laptop.config.allowedUnfree;
        };

        "pi@Home-Server" = homeManagerConfiguration {
          module = ./hosts/home-server/home.nix;

          pkgs = import nixpkgs {
            system = "aarch64-linux";

            overlays = [
              outputs.overlays.additions
              outputs.overlays.modifications
            ];
          };

          nixosAllowedUnfree = outputs.nixosConfigurations.Home-Server.config.allowedUnfree;
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

        "alvaro.fresquet@Alvaros-MacBook-Pro.local" = homeManagerConfiguration {
          module = ./hosts/work/home.nix;

          pkgs = import nixpkgs {
            system = "aarch64-darwin";

            overlays = [
              outputs.overlays.additions
              outputs.overlays.modifications
            ];
          };
        };
      };
    };
}
