{ self, ... }:
{
  flake.modules.nixos.obsidian =
    { pkgs, ... }:
    {
      imports = [ self.modules.nixos.allowed-unfree ];

      environment.systemPackages = [ pkgs.obsidian ];

      allowedUnfree = [ "obsidian" ];
    };
}
