{
  flake.modules.homeManager.zellij =
    { lib, config, ... }:
    {
      programs.zellij.enable = true;

      home.shellAliases.z = lib.getExe config.programs.zellij.package;
    };
}
