# LibrePods starts a BLE discovery whenever it launches without the AirPods'
# AAP socket open (always, at login) and only stops it on the AirPods'
# metadata packet, which doesn't arrive on every connection. BlueZ keeps
# discovering while any client asks, so the adapter scans forever: other
# tools can't stop the scan and it costs battery. Stop it as soon as the AAP
# connection is up; it restarts on disconnect, which is when it's needed.
_final: prev: {
  librepods = prev.librepods.overrideAttrs (old: {
    postPatch =
      (
        if old.version != "0.2.5" then
          throw "librepods ${old.version}: check whether it still scans while connected, then update or drop overlays/librepods-stop-scan.nix"
        else
          ""
      )
      + ''
        substituteInPlace main.cpp --replace-fail \
          'LOG_INFO("Connected to device, sending initial packets");' \
          'LOG_INFO("Connected to device, sending initial packets"); m_bleManager->stopScan();'
      ''
      + (old.postPatch or "");
  });
}
