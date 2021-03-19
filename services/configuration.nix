{ config, pkgs, ... }:

let
  packet-broker = pkgs.packet-broker;
in {
  systemd.services = {
    packet-broker = {
      description = "Packet Broker Daemon (bf_switchd)";
      after = [ "networking.service" ];
      requires = [ "networking.service" ];
      serviceConfig = {
        ExecStart = "${packet-broker.moduleWrapper}/bin/packet_broker-module-wrapper /var/run/packet-broker";
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
        ExecStart = "${packet-broker.configd}/bin/configd.py --config-dir /etc/packet-broker --ifmibs-dir /var/run/packet-broker-snmp";
        ExecStartPre = "+/bin/mkdir -p /var/run/packet-broker-snmp";
        ExecReload = "${packet-broker.configd}/bin/brokerctl reload";
        Restart = "on-failure";
        Type = "simple";
      };
    };
    snabb-snmp-agent = {
      description = "Snabb SNMP subagent for interface MIBs";
      after = [ "snmpd.service" ];
      requires = [ "snmpd.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.SNMPAgent}/bin/interface --ifindex=/etc/snmp/ifindex --shmem-dir=/var/run/packet-broker-snmp";
        ExecStartPre = "+/bin/mkdir -p /var/run/packet-broker-snmp";
        Group = "Debian-snmp";
        User = "Debian-snmp";
        Type = "simple";
      };
    };
  };
}
