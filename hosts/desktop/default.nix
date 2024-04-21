{ config, inputs, ... }:
let
  inherit (config) username;
in
{
  imports = [
    ./configuration.nix

    inputs.home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${username} = import ./home.nix;
        extraSpecialArgs = {
          inherit inputs;

          args = {
            inherit username;
            hyprland.enable = config.hyprland.enable;
          };
        };
      };
    }
  ];

}
