{
  description = "My NixOS flake";

  outputs = { nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      font-awesome-bump = inputs.nixpkgs-font-awesome-bump.legacyPackages.${system};
      args = {
        inherit inputs;
        inherit system;
        hostname = "nixos";
        username = "afresquet";
        inherit font-awesome-bump;

        shell = pkgs.nushell;
      };
    in
    {
      nixosConfigurations = with args; {
        "${hostname}" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = args;
          modules = [
            ./hosts/desktop/configuration.nix

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
}
