{ lib, config, ... }: {
  options = {
    cli-tools.enable = lib.mkEnableOption "cli-tools";
  };

  imports = [
    ./bat.nix
    ./btop.nix
    ./eza.nix
    ./fzf.nix
    ./jq.nix
    ./ripgrep.nix
    ./thefuck.nix
  ];

  config = lib.mkIf config.cli-tools.enable {
    bat.enable = true;
    btop.enable = true;
    eza.enable = true;
    fzf.enable = true;
    jq.enable = true;
    ripgrep.enable = true;
    thefuck.enable = true;
  };
}
