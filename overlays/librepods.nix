# Two fixes to LibrePods 0.2.5; the build fails on another version so each gets
# rechecked against upstream.
#
# No scanning: LibrePods runs a BLE discovery whenever the AirPods aren't
# connected (at login, on wake, after every disconnect) and only stops it on
# their metadata packet, which doesn't arrive on every connection. BlueZ keeps
# discovering while any client asks, so the adapter scans until the AirPods
# connect, or forever: other tools can't stop it and it costs battery. All the
# scan gives is battery and in-ear status read from their broadcasts while
# disconnected; it never connects them, which is done by hand anyway. Make
# startScan a no-op; connected status comes over AAP as before.
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
          throw "librepods ${old.version}: check whether it still scans whenever the AirPods are disconnected and still turns the card profile off out of ear, then update or drop overlays/librepods.nix"
        else
          ""
      )
      + ''
        substituteInPlace ble/blemanager.cpp --replace-fail \
          '    discoveryAgent->start(QBluetoothDeviceDiscoveryAgent::LowEnergyMethod);' \
          '    // discoveryAgent->start(QBluetoothDeviceDiscoveryAgent::LowEnergyMethod);'
        substituteInPlace media/mediacontroller.cpp --replace-fail \
          '    removeAudioOutputDevice();' \
          '    // removeAudioOutputDevice();'
      ''
      + (old.postPatch or "");
  });
}
