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

      tertiaryMonitor = builtins.elemAt config.monitors 2;
      tertiaryMonitorRule = "monitor:${tertiaryMonitor.name}";
    in
    {
      browser = [ primaryMonitorRule ];
      terminal = [ primaryMonitorRule ];
      file-manager = [ primaryMonitorRule ];

      twitter = [ secondaryMonitorRule ];
      obsidian = [ secondaryMonitorRule ];

      discord = [ tertiaryMonitorRule ];
      whatsapp = [ tertiaryMonitorRule ];
      music = [ tertiaryMonitorRule ];
      _1password = [ tertiaryMonitorRule ];
    };
}
