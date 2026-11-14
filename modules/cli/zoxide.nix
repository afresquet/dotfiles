{
  flake.modules.homeManager.zoxide = _: {
    config = {
      programs.zoxide = {
        enable = true;

        options = [ "--cmd cd" ];
      };

      home.sessionVariables._ZO_DOCTOR = "0";
    };
  };
}
