{
  description = "My NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      args = {
        inherit inputs;

        system = "x86_64-linux";

        hostname = "afresquet-pc";
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
