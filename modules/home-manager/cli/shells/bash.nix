{ lib, config, ... }:
let
  cfg = config.bash;
in
{
  options = {
    bash.enable = lib.mkEnableOption "bash" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.bash = {
      enable = true;
      # On hosts where bash is the login shell but nushell is the preferred
      # interactive shell (currently home-server, so Ghostty's ssh-terminfo
      # wrapper — bash-syntax — works against the non-interactive remote
      # shell), hand off to the real shell once an interactive bash starts.
      initExtra = lib.mkIf ((config.shell.pname or "") != "bash") ''
        if [[ $- == *i* ]] && [[ -z "$IN_NESTED_SHELL" ]]; then
          export IN_NESTED_SHELL=1
          exec ${lib.getExe config.shell}
        fi
      '';
    };
  };
}
