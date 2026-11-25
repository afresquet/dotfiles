{ self, ... }:
{
  flake.modules.homeManager.antigravity-cli = _: {
    imports = [ self.modules.homeManager.allowed-unfree ];

    programs.antigravity-cli = {
      enable = true;
      mutableSettings = true;
    };

    allowedUnfree = [ "antigravity-cli" ];
  };
}
