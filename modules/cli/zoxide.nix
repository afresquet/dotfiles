{
  flake.modules.homeManager.zoxide = _: {
    programs.zoxide = {
      enable = true;

      options = [ "--cmd cd" ];
    };

    home.sessionVariables._ZO_DOCTOR = "0";
  };
}
