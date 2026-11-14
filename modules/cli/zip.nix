{
  flake.modules.homeManager.zip =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = with pkgs; [
          zip
          xz
          unzip
          p7zip
          zstd
        ];
      };
    };
}
