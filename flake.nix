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
        system: module:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
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
        "afresquet@Alvaro-Desktop" = homeManagerConfiguration "x86_64-linux" ./hosts/desktop/home.nix;

        "afresquet@Alvaro-Laptop" = homeManagerConfiguration "x86_64-linux" ./hosts/laptop/home.nix;

        "afresquet@mac-afresquet" = homeManagerConfiguration "x86_64-darwin" ./hosts/work/home.nix;
      };
    };
}
