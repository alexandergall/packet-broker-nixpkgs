{ stdenv, lib, version, makeWrapper, coreutils, utillinux, gnused,
  gawk, jq, curl, systemd, gnutar, gzip, git, kmod }:

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
      "${lib.strings.makeBinPath [ coreutils utillinux gnused gawk
                                   jq curl systemd gnutar gzip git kmod ]}"

    mkdir -p $out/etc/snmp $out/var/lib/snmp
    cp ${./snmpd.conf} $out/etc/snmp/snmpd.conf
    cp ${./ifindex} $out/etc/snmp/ifindex
    cp ${./interface.conf} $out/var/lib/snmp/interface.conf
  '';
}
