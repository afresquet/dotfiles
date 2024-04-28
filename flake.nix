{
  description = "My NixOS flake";

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
        desktop = nixosSystem [
          ./hosts/desktop
        ];

        laptop = nixosSystem [
          ./hosts/laptop
        ];
      };
    };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";

    nix-colors.url = "github:misterio77/nix-colors";
  };
}
