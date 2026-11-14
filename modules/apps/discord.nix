{ self, ... }:
{
  flake.modules.nixos.discord =
    {
      pkgs,
      ...
    }:
    {
      imports = [ self.modules.nixos.allowed-unfree ];

      config = {
        environment.systemPackages = with pkgs; [
          discord
        ];

        allowedUnfree = [
          "discord"
          "discord-unwrapped"
        ];
      };
    };
}
