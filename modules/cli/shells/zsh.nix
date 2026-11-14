{
  flake.modules.homeManager.zsh =
    { lib, config, ... }:
    {
      config = {
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
          initContent = lib.mkIf config.programs.nushell.enable ''
            if [[ -o interactive ]] && [[ -z "$IN_NESTED_SHELL" ]]; then
              export IN_NESTED_SHELL=1
              exec ${lib.getExe config.programs.nushell.package}
            fi
          '';
        };
      };
    };
}
