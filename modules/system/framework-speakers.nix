# Makes the Framework Laptop 13 (Ryzen 7040) speakers listenable: EasyEffects
# runs Framework's own preset for them
# (https://github.com/FrameworkComputer/linux-docs/tree/main/easy-effects).
# nixos-hardware's `laptop13.audioEnhancement` sounds muffled on them, and a
# PipeWire filter-chain port of this preset sounded duller than EasyEffects.
let
  speakers = "alsa_output.pci-0000_c1_00.6.analog-stereo";

  linuxDocs = "https://raw.githubusercontent.com/FrameworkComputer/linux-docs/e5289ecc283e0e940536ce48e0ed789adf0280be/easy-effects";

  impulse = "IR_22ms_27dB_5t_15s_0c";
in
{
  flake.modules.homeManager.framework-speakers =
    { pkgs, ... }:
    {
      services.easyeffects = {
        enable = true;
        # Only the speakers get the preset (autoloaded below); headphones,
        # Bluetooth and HDMI fall back to no effects.
        extraPresets.off.output = {
          blocklist = [ ];
          plugins_order = [ ];
        };
        settings = {
          Window = {
            outputAutoloadingUsesFallback = true;
            outputAutoloadingFallbackPreset = "off";
            # It only runs in the background; nothing to click on.
            showTrayIcon = false;
          };
          EffectsPipelines.bypass = false;
        };
      };

      xdg.dataFile = {
        "easyeffects/output/fw13.json".source = pkgs.fetchurl {
          url = "${linuxDocs}/fw13-easy-effects.json";
          hash = "sha256-SNSUu858z6+RdcRH9xgBTJeSDJmLu2RINx+OUaWGH3A=";
        };
        # The preset's convolver loads this by name.
        "easyeffects/irs/${impulse}.irs".source = pkgs.fetchurl {
          url = "${linuxDocs}/irs/${impulse}.irs";
          hash = "sha256-IxDXNhnTg/NrhPxA5+6u/meEnlX720eoQPyoJfbuge0=";
        };
        # Named after the device and its route's description; the headphone
        # jack is the same device on the "Headphones" route.
        "easyeffects/autoload/output/${speakers}:Speakers.json".text = builtins.toJSON {
          device = speakers;
          device-description = "Ryzen HD Audio Controller Analog Stereo";
          device-profile = "Speakers";
          preset-name = "fw13";
        };
      };
    };
}
