{
  imports = [
    ../home.nix
    ./settings.nix
  ];

  stylix.opacity.terminal = 0.95;

  programs.helix.settings.editor.clipboard-provider = "termcode";

  agentTelegram.enable = true;

  # Real copies rather than symlinks so Spotlight indexes the apps.
  targets.darwin.copyApps.enable = true;
  targets.darwin.linkApps.enable = false;
}
