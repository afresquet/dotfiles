{ ... }:

{
  programs.starship = {
    enable = true;

    settings = {
      add_newline = true;
    };

    enableBashIntegration = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;
  };
}
