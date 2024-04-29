{
  description = "My NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";

    stylix.url = "github:danth/stylix";
  };

  outputs = { nixpkgs, ... }@inputs:
    let
      nixosSystem = modules:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = modules ++ [
            ./modules/overlays
          ];
        };
    in
    {
      nixosConfigurations = {
        Alvaro-Desktop = nixosSystem [
          ./hosts/desktop
        ];

        Alvaro-Laptop = nixosSystem [
          ./hosts/laptop
        ];
      };
    };
}
