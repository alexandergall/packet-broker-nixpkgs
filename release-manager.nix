{ stdenv, lib, version, makeWrapper, coreutils, utillinux, gnused,
  jq, curl, systemd, gnutar, gzip, diffutils }:

stdenv.mkDerivation {
  pname = "packet-broker-release-manager";
  inherit version;
  buildInputs = [ makeWrapper ];
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/bin
    cp ${./packet-broker-release-manager} $out/bin/packet-broker-release-manager
    chmod a+x $out/bin/*
    patchShebangs $out/bin
    wrapProgram $out/bin/packet-broker-release-manager --set PATH \
      "${lib.strings.makeBinPath [ coreutils utillinux gnused jq curl systemd gnutar gzip diffutils ]}"
  '';
}
