{ stdenv, lib, version, makeWrapper, coreutils, utillinux, gnused,
  jq, curl, systemd, gnutar, gzip }:

stdenv.mkDerivation {
  pname = "release-manager";
  inherit version;
  buildInputs = [ makeWrapper ];
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/bin
    cp ${./release-manager} $out/bin/release-manager
    chmod a+x $out/bin/*
    patchShebangs $out/bin
    substituteInPlace $out/bin/release-manager --subst-var-by PATH \
      "${lib.strings.makeBinPath [ coreutils utillinux gnused jq curl systemd gnutar gzip ]}"
  '';
}
