{ self, ... }:
{
  flake.modules.homeManager.copilot = _: {
    imports = [ self.modules.homeManager.allowed-unfree ];

    config = {
      programs.github-copilot-cli.enable = true;

      allowedUnfree = [ "github-copilot-cli" ];
    };
  };
}
