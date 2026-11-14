{ inputs, self, ... }:
{
  flake.modules.homeManager.tilth =
    { pkgs, ... }:
    {
      imports = [ self.modules.homeManager.skills ];

      home.packages = [ pkgs.tilth ];

      skills.sources.tilth = "${inputs.tilth}/skills/SKILL.md";
    };
}
