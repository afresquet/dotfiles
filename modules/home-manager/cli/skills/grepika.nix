{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.skills.grepika;

  skillsDir = "${inputs.skills.grepika}/plugins/grepika/skills";
  skillNames = builtins.attrNames (builtins.readDir skillsDir);

  # Home Manager exposes shared MCP servers to Claude through a plugin named
  # "hm", which namespaces the tools the upstream skills refer to.
  mkClaudeSkill =
    name:
    pkgs.runCommandLocal "grepika-claude-skill-${name}" { } ''
      cp -r ${skillsDir}/${name} $out
      chmod -R u+w $out
      find $out -type f -exec sed -i 's/mcp__grepika__/mcp__plugin_hm_grepika__/g' {} +
    '';
in
{
  options.skills.grepika.enable = lib.mkEnableOption "Grepika skills" // {
    default = config.skills.enable;
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.grepika ];

    programs.mcp = {
      enable = true;
      servers.grepika = {
        command = lib.getExe pkgs.grepika;
        args = [ "--mcp" ];
      };
    };

    skills.sources = lib.genAttrs skillNames (name: "${skillsDir}/${name}");
    skills.claudeOverrides = lib.genAttrs skillNames mkClaudeSkill;
    skills.copilotExcludes = skillNames;
  };
}
