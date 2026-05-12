{ lib, config, ... }:
let
  cfg = config.zsh;
in
{
  options = {
    zsh.enable = lib.mkEnableOption "zsh" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      # On hosts where zsh is the login shell but nushell is the preferred
      # interactive shell (currently mac-mini, where macOS pins the login
      # shell to zsh), hand off to the real shell once an interactive zsh
      # starts. Non-interactive zsh (ssh-run remote commands) doesn't source
      # .zshrc, so ssh-driven tooling like Ghostty's ssh-terminfo wrapper
      # still runs against POSIX zsh.
      initContent = lib.mkIf ((config.shell.pname or "") != "zsh") ''
        if [[ -o interactive ]] && [[ -z "$IN_NESTED_SHELL" ]]; then
          export IN_NESTED_SHELL=1
          exec ${lib.getExe config.shell}
        fi
      '';
    };
  };
}
