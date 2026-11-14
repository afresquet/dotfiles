{ self, ... }:
{
  flake.modules.homeManager.copilot = _: {
    imports = [ self.modules.homeManager.allowed-unfree ];

    programs.github-copilot-cli.enable = true;

    allowedUnfree = [ "github-copilot-cli" ];
  };
}
