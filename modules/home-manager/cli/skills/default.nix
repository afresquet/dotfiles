{
  lib,
  config,
  utils,
  ...
}:
let
  cfg = config.skills;
in
{
  imports = utils.importDir ./.;

  options.skills = {
    enable = lib.mkEnableOption "AI agent skills" // {
      default = true;
    };

    sources = lib.mkOption {
      type = with lib.types; attrsOf (either lines path);
      default = { };
      description = "Skills shared by every AI agent, by name. Inline content, a SKILL.md file or a skill directory.";
    };

    claudeOverrides = lib.mkOption {
      type = with lib.types; attrsOf (either lines path);
      default = { };
      description = "Claude-specific replacements for entries in `skills.sources`.";
    };

    copilotExcludes = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "Entries in `skills.sources` that GitHub Copilot CLI can't use.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.claude-code = {
      skills = cfg.sources // cfg.claudeOverrides;
      enableMcpIntegration = true;
    };

    programs.codex = {
      skills = cfg.sources;
      enableMcpIntegration = true;
    };

    # Third-party MCP servers are blocked by the organization's Copilot policy.
    programs.github-copilot-cli.skills = removeAttrs cfg.sources cfg.copilotExcludes;
  };
}
