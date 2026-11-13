{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.vscode;
in
{
  options = {
    vscode.enable = lib.mkEnableOption "Visual Studio Code" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      vscode
    ];

    allowedUnfree = [ "vscode" ];
  };
}
