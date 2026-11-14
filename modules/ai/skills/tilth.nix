{ inputs, self, ... }:
{
  flake.modules.homeManager.tilth =
    {
      pkgs,
      ...
    }:
    {
      imports = [ self.modules.homeManager.skills ];

      config = {
        home.packages = [ pkgs.tilth ];

        skills.sources.tilth = "${inputs.tilth}/skills/SKILL.md";
      };
    };
}
