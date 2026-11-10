{ lib, config, ... }:
{
  imports = [
    ../home.nix
    ./settings.nix
  ];

  herdr-desktop.enable = true;

  stylix.opacity.terminal = 0.85;

  btop.rocmSupport = true;

  hyprlock.enable = true;

  hyprland.workspaces =
    let
      onMonitor =
        index: names:
        lib.genAttrs names (_: {
          extraRules.monitor = (builtins.elemAt config.monitors index).name;
        });
    in
    onMonitor 0 [
      "browser"
      "terminal"
      "file-manager"
      "obsidian"
      "steam"
      "bambu-studio"
      "herdr"
    ]
    // onMonitor 1 [
      "discord"
      "messaging"
      "music"
      "_1password"
    ];
}
