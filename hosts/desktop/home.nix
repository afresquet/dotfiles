{ config, ... }:
{
  imports = [
    ../home.nix
    ./settings.nix
  ];

  hyprland.workspace.extraRules =
    let
      primaryMonitor = builtins.elemAt config.monitors 0;
      primaryMonitorRule = "monitor:${primaryMonitor.name}";

      secondaryMonitor = builtins.elemAt config.monitors 1;
      secondaryMonitorRule = "monitor:${secondaryMonitor.name}";
    in
    {
      browser = [ primaryMonitorRule ];
      terminal = [ primaryMonitorRule ];
      file-manager = [ primaryMonitorRule ];

      discord = [ secondaryMonitorRule ];
      obsidian = [ secondaryMonitorRule ];
      whatsapp = [ secondaryMonitorRule ];
      music = [ secondaryMonitorRule ];
      _1password = [ secondaryMonitorRule ];
    };
}
