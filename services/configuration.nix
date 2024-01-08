{moduleWrapper, configd }:

{ config, pkgs, ... }:

{
  ## Get rid of the warning about missing stateVersion during
  ## evaluation of the NixOS configuration. This can be kept in sync
  ## with the nixpkgs version.
  system.stateVersion = "23.11";
  systemd.services = {
    packet-broker = {
      description = "Packet Broker Daemon (bf_switchd)";
      after = [ "networking.service" ];
      requires = [ "networking.service" ];
      serviceConfig = {
        ExecStart = "${moduleWrapper}/bin/packet_broker-module-wrapper /var/run/packet-broker";
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
    snabb-snmp-agent = {
      description = "Snabb SNMP subagent for interface MIBs";
      after = [ "snmpd.service" ];
      requires = [ "snmpd.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.SNMPAgent}/bin/interface --ifindex=/etc/snmp/ifindex --shmem-dir=/var/run/packet-broker-snmp";
        ExecStartPre = "+/bin/mkdir -p /var/run/packet-broker-snmp";
        Type = "simple";
      };
    };
    snmpd = {
      description = "Simple Network Management Protocol (SNMP) Daemon";
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.net-snmp}/sbin/snmpd -Lsd -Lf /dev/null -I -smux,mteTrigger,mteTriggerConf -I -ifTable -f -p /run/snmpd.pid -c /etc/snmp/snmpd.conf";
        ExecStartPre = "/bin/mkdir -p /var/run/agentx";
        ExecReload = "/bin/kill -HUP $MAINPID";
      };
    };
  };
}
