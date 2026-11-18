# Two fixes to LibrePods 0.2.5; the build fails on another version so each gets
# rechecked against upstream.
#
# Endless scan: LibrePods starts a BLE discovery whenever it launches without
# the AirPods' AAP socket open (always, at login) and only stops it on the
# AirPods' metadata packet, which doesn't arrive on every connection. BlueZ
# keeps discovering while any client asks, so the adapter scans forever: other
# tools can't stop the scan and it costs battery. Stop it as soon as the AAP
# connection is up; it restarts on disconnect, which is when it's needed.
#
# Lost output: with both AirPods out of the ears it sets their card profile to
# "off", and a long-running instance (across a suspend) doesn't always turn
# A2DP back on when they reconnect, leaving them connected with no sink. Never
# switch the profile off; ear detection still pauses playback.
_final: prev: {
  librepods = prev.librepods.overrideAttrs (old: {
    postPatch =
      (
        if old.version != "0.2.5" then
          throw "librepods ${old.version}: check whether it still scans while connected and still turns the card profile off out of ear, then update or drop overlays/librepods.nix"
        else
          ""
      )
      + ''
        substituteInPlace main.cpp --replace-fail \
          'LOG_INFO("Connected to device, sending initial packets");' \
          'LOG_INFO("Connected to device, sending initial packets"); m_bleManager->stopScan();'
        substituteInPlace media/mediacontroller.cpp --replace-fail \
          '    removeAudioOutputDevice();' \
          '    // removeAudioOutputDevice();'
      ''
      + (old.postPatch or "");
  });
}
