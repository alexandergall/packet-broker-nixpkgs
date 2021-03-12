{ config, pkgs, ... }:

let
  broker = pkgs.packetBroker.packetBroker;
  configd = pkgs.packetBroker.configd;
in {
  nixpkgs.overlays = import ../../overlay.nix ++ import ../overlay.nix;

  systemd.services = {
    packet-broker = {
      description = "Packet Broker Daemon (bf_switchd)";
      serviceConfig = {
        ExecStart = "${broker.makeModuleWrapper}/bin/packet_broker-module-wrapper /var/run/packet-broker";
        ExecStartPre = "+/bin/mkdir -p /var/run/packet-broker";
        Restart = "on-failure";
        Type = "simple";
      };
    };
    packet-broker-configd = {
      description = "Packet Broker Configuration Daemon";
      after = [ "packet-broker.service" ];
      requires = [ "packet-broker.service" ];
      serviceConfig = {
        ExecStart = "${configd}/bin/configd.py --config-dir /etc/packet-broker --ifmibs-dir /var/run/packet-broker-snmp";
        ExecStartPre = "+/bin/mkdir -p /var/run/packet-broker-snmp";
        ExecReload = "${configd}/bin/brokerctl reload";
        Restart = "on-failure";
        Type = "simple";
      };
    };
  };
}
