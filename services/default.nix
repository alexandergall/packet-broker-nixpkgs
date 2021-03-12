{ pkgs }:

let
  eval = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    inherit pkgs;
    modules = [ ./configuration.nix ];
  };
  units = eval.config.systemd.units;

  ## NixOS doesn't manage the [Install] section of units because it
  ## requires a stateful interaction with "systemctl enable" to
  ## activate the unit. But [Install] is required on a non-NixOS
  ## system, hence we add that section here.
  addWantedBy = name: wantedBy:
    let
      unit = units.${name}.unit;
    in pkgs.runCommand "${name}" {} ''
      mkdir $out
      cp ${unit}/*service $out
      chmod a+w $out/*.service
      cat <<EOF >>$out/*.service
      [Install]
      WantedBy=${wantedBy}
      EOF
    '';
in {
  packet-broker-service = addWantedBy "packet-broker.service" "multi-user.target";
  packet-broker-configd-service = addWantedBy "packet-broker-configd.service" "packet-broker.service";
  snabb-snmp-agent-service = addWantedBy "snabb-snmp-agent.service" "snmpd.service";
}
