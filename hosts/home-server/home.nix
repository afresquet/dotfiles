{
  imports = [
    ../home-base.nix
    ./settings.nix
  ];

  home.stateVersion = "25.05";

  programs.helix.settings.editor.clipboard-provider = "termcode";

  agentTelegram.enable = true;
  issueAgent = {
    enable = true;
    appId = 5747695;
  };
}
