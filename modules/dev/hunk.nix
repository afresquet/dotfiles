{ inputs, ... }:
{
  flake.modules.homeManager.hunk =
    { pkgs, ... }:
    {
      imports = [ inputs.hunk.homeManagerModules.default ];

      programs.hunk = {
        enable = true;
        package = pkgs.hunk;
        enableClaudeIntegration = true;
      };
    };
}
