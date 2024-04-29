{ lib, config, ... }: {
  options = {
    fzf.enable = lib.mkEnableOption "fzf";
  };

  config = {
    programs.fzf.enable = config.fzf.enable;
  };
}
