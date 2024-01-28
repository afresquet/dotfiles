{ ... }:

{
  programs = {
    nushell = {
      enable = true;
      extraConfig = ''
        $env.config = {
          show_banner: false,
        }
      '';
    };

    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };
  };
}
