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

            # https://github.com/NixOS/nixpkgs/pull/285394
            inherit (inputs.font-awesome-bump.legacyPackages."x86_64-linux") font-awesome;
          };
        };
      };
    }
  ];

}
