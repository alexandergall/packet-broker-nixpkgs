{ stdenv, lib, version, nixProfile, makeWrapper, coreutils, utillinux,
  gnused, gawk, jq, curl, systemd, gnutar, gzip, git, kmod, ncurses }:

stdenv.mkDerivation {
  pname = "release-manager";
  inherit version;
  buildInputs = [ makeWrapper ];
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/bin
    substitute ${./release-manager} $out/bin/release-manager \
      --subst-var-by PATH \
        "${lib.strings.makeBinPath [ coreutils utillinux gnused gawk
                                     jq curl systemd gnutar gzip git kmod ncurses ]}" \
      --subst-var-by PROFILE ${nixProfile}
    chmod a+x $out/bin/*
    patchShebangs $out/bin

    mkdir -p $out/etc/snmp $out/var/lib/snmp
    cp ${./snmpd.conf} $out/etc/snmp/snmpd.conf
    cp ${./ifindex} $out/etc/snmp/ifindex
    cp ${./interface.conf} $out/var/lib/snmp/interface.conf
  '';
}
