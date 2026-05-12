{ lib, config, isLinux, ... }:
let
  cfg = config.ghostty;
in
{
  options = {
    ghostty.enable = lib.mkEnableOption "ghostty" // {
      default = isLinux;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ghostty = {
      enable = true;

      settings = {
        window-decoration = false;
        # Ship xterm-ghostty terminfo to remote hosts over SSH so less/tmux/
        # nvim don't complain about a missing terminal entry. Ghostty's shell
        # integration wraps `ssh`, runs `infocmp` locally, and pipes `tic`
        # on the remote into ~/.terminfo on first connect.
        #
        # Parser is additive (parsePackedStruct in ghostty's src/cli/args.zig
        # starts from struct defaults), so naming just `ssh-terminfo` keeps
        # cursor/title/path defaults on. Use `no-X` to disable individual flags.
        shell-integration-features = "ssh-terminfo";
      };
    };
  };
}
