{ self, ... }:
{
  flake.modules.nixos.obsidian =
    {
      pkgs,
      ...
    }:
    {
      imports = [ self.modules.nixos.allowed-unfree ];

      config = {
        environment.systemPackages = [ pkgs.obsidian ];

        allowedUnfree = [ "obsidian" ];
      };
    };
}
