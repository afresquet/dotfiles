# Makes the Framework Laptop 13 (Ryzen 7040) speakers listenable: a PipeWire
# sink that plays through a port of Framework's EasyEffects preset
# (https://github.com/FrameworkComputer/linux-docs/tree/main/easy-effects), with
# the plugins EasyEffects uses. nixos-hardware's `laptop13.audioEnhancement`
# sounds muffled on them.
let
  speakers = "alsa_output.pci-0000_c1_00.6.analog-stereo";

  # The plugins take linear gains, and Nix has no pow: 10 ** (db / 20).
  db = {
    "-24" = 0.0630957;
    "-16" = 0.158489;
    "-12" = 0.251189;
    "-9" = 0.354813;
    "5" = 1.778279;
  };
in
{
  flake.modules.nixos.framework-speakers =
    { lib, pkgs, ... }:
    let
      # Correction measured on a Laptop 13, the same file Framework ships.
      impulse = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/cab404/framework-dsp/6e5b8e7a5d1f422bcaa2f237f28223fe2292ca38/config/irs/IR_22ms_27dB_5t_15s_0c.irs";
        hash = "sha256-IxDXNhnTg/NrhPxA5+6u/meEnlX720eoQPyoJfbuge0=";
      };

      convolver = channel: {
        type = "builtin";
        label = "convolver";
        name = "convolver_${toString channel}";
        config = {
          filename = "${impulse}";
          inherit channel;
          # EasyEffects' autogain, 1 / sqrt(energy of the impulse at 48 kHz),
          # plus the preset's 6 dB.
          gain = 2.429396;
        };
      };

      # Compressor bands, each up to the next one's `from`.
      bands = [
        {
          al = db."-16";
          kn = db."-12";
          cr = 5.0;
          at = 150.0;
          rt = 300.0;
        }
        {
          from = 250.0;
          al = db."-24";
          kn = db."-9";
          cr = 3.0;
          at = 150.0;
          rt = 200.0;
          mk = db."5";
        }
        {
          from = 1250.0;
          al = db."-24";
          kn = db."-9";
          cr = 3.0;
          at = 100.0;
          rt = 150.0;
          mk = db."5";
        }
        {
          from = 5000.0;
          al = db."-24";
          kn = db."-9";
          cr = 4.0;
          at = 80.0;
          rt = 120.0;
          mk = db."5";
        }
      ];

      bandControls = lib.mergeAttrsList (
        lib.imap0 (
          i: band:
          lib.mapAttrs' (name: lib.nameValuePair "${name}_${toString i}") (removeAttrs band [ "from" ])
          // lib.optionalAttrs (band ? from) {
            "cbe_${toString i}" = 1;
            "sf_${toString i}" = band.from;
          }
        ) bands
      );

      lsp = plugin: name: control: {
        type = "lv2";
        plugin = "http://lsp-plug.in/plugins/lv2/${plugin}";
        inherit name control;
      };

      nodes = [
        (lsp "filter_stereo" "highpass" {
          ft = 1; # high-pass
          s = 7; # x16
          f = 60.0;
          w = 1.0;
          q = 16.0;
        })
        (convolver 0)
        (convolver 1)
        (lsp "sc_mb_compressor_stereo" "compressor" (
          bandControls
          // {
            envb = 0; # no envelope boost
            # On by default.
            cbe_4 = 0;
            cbe_6 = 0;
          }
        ))
        {
          type = "lv2";
          plugin = "http://calf.sourceforge.net/plugins/StereoTools";
          name = "stereo";
          control.stereo_base = 0.3;
        }
        (lsp "sc_limiter_stereo" "limiter" {
          lk = 4.0;
          at = 2.0;
          rt = 8.0;
          alr = 0;
        })
      ];

      link = output: input: { inherit output input; };

      stereoLink = from: to: [
        (link "${from}:out_l" "${to}:in_l")
        (link "${from}:out_r" "${to}:in_r")
      ];

      channels = {
        "audio.channels" = 2;
        "audio.position" = [
          "FL"
          "FR"
        ];
      };

      filterGraph = channels // {
        "node.description" = "Framework Speakers";
        "media.name" = "Framework Speakers";
        "filter.graph" = {
          inherit nodes;
          links = [
            (link "highpass:out_l" "convolver_0:In")
            (link "highpass:out_r" "convolver_1:In")
            (link "convolver_0:Out" "compressor:in_l")
            (link "convolver_1:Out" "compressor:in_r")
          ]
          ++ stereoLink "compressor" "stereo"
          ++ stereoLink "stereo" "limiter";
          inputs = [
            "highpass:in_l"
            "highpass:in_r"
          ];
          outputs = [
            "limiter:out_l"
            "limiter:out_r"
          ];
          # The sink's volume goes after the chain. Ahead of it, turning it down
          # would leave the compressor nothing to compress.
          "capture.volumes" = [
            {
              control = "limiter:g_out";
              min = 0.0;
              max = 1.0;
            }
          ];
        };
        "capture.props" = channels // {
          "node.name" = "framework-speakers";
          "media.class" = "Audio/Sink";
          "node.virtual" = false;
          "device.api" = "dsp";
          "device.icon-name" = "audio-card-analog-pci";
          # What the speakers have on their own: below Bluetooth (1010) and USB
          # (1100), which take over when connected.
          "priority.session" = 1009;
          "priority.driver" = 1009;
          "state.default-volume" = 0.343;
        };
        "playback.props" = channels // {
          "node.name" = "framework-speakers.output";
          "target.object" = speakers;
          "node.passive" = true;
        };
      };
    in
    {
      services.pipewire.wireplumber = {
        extraLv2Packages = with pkgs; [
          calf
          lsp-plugins
        ];
        extraConfig."99-framework-speakers" = {
          # hide-parent hides the raw speakers from clients but not from
          # WirePlumber, which makes them the default sink when the priorities
          # tie, and then nothing can connect to it.
          "monitor.alsa.rules" = [
            {
              matches = [ { "node.name" = speakers; } ];
              actions.update-props."priority.session" = 900;
            }
          ];
          "node.software-dsp.rules" = [
            {
              matches = [ { "node.name" = speakers; } ];
              actions.create-filter = {
                filter-graph = filterGraph;
                # Both have a volume, and they compound.
                hide-parent = true;
              };
            }
          ];
          "wireplumber.profiles".main."node.software-dsp" = "required";
        };
      };
    };
}
