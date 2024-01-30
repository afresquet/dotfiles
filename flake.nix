{
  description = "My NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";

    nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      args = {
        inherit inputs;
        system = "x86_64-linux";
        hostname = "nixos";
        username = "afresquet";
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
