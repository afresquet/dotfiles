{
  description = "My NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-font-awesome-bump.url = "github:afresquet/nixpkgs/bump-font-awesome";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";

    nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = { self, nixpkgs, home-manager, nixpkgs-font-awesome-bump, ... }@inputs:
    let
      system = "x86_64-linux";
      font-awesome-bump = nixpkgs-font-awesome-bump.legacyPackages.${system};
      args = {
        inherit inputs;
        inherit system;
        hostname = "nixos";
        username = "afresquet";
        inherit font-awesome-bump;
      };
    in
    {
      nixosConfigurations = with args; {
        "${hostname}" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = args;
          modules = [
            ./system

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.${username} = import ./home;
                extraSpecialArgs = args;
              };
            }
          ];
        };
      };
    };
}
