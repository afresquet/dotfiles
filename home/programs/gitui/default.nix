{ config, ... }: {
  programs.gitui = {
    enable = config.git.enable;
    keyConfig = builtins.readFile ./key_bindings.ron;
  };
}
