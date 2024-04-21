{ pkgs, config, ... }: {
  programs.git = {
    enable = true;
    userName = config.username;
    userEmail = "29437693+afresquet@users.noreply.github.com";
    extraConfig = {
      init.defaultBranch = "main";
      core.editor = "hx";
      user.signingkey = "/home/${config.username}/.ssh/id_ed25519.pub";
      gpg.format = "ssh";
      commit.gpgsign = true;
    };
    delta = {
      enable = true;
      options = {
        navigate = true;
        light = false;
      };
    };
  };

  home.packages = with pkgs; [
    lazygit
  ];
}
