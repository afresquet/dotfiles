{ lib, config, ... }: {
  options = {
    git.enable = lib.mkEnableOption "Git";
  };

  imports = [
    ./gitui
  ];

  config = {
    programs.git = {
      enable = config.git.enable;
      userName = config.username;
      userEmail = "29437693+afresquet@users.noreply.github.com";
      extraConfig = {
        init.defaultBranch = "main";
        core.editor = "hx";
        user.signingkey = "/home/${config.username}/.ssh/id_ed25519.pub";
        gpg.format = "ssh";
        commit.gpgsign = true;
        push.autoSetupRemote = true;
      };
      delta = {
        enable = true;
        options = {
          navigate = true;
          light = false;
        };
      };
    };

    programs.lazygit.enable = config.git.enable;
  };
}
