{ pkgs, inputs, ... }: {
  fonts.packages = with pkgs; [
    inputs.font-awesome-bump.legacyPackages."x86_64-linux".font-awesome
    nerdfonts
  ];
}
