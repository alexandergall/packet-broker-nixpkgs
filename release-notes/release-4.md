# Packet Broker Release 4

Move to SDE 9.8.0.

New features for the flow-mirror functionality

   * Mirroring can be restricted to a subset of the ingress ports by
     providing the list of ports with the new `ingress-ports`
     property.
   * Non-IP (IPv4 or IPv6) packets can be matched with the new
     `non-ip` property. In this case, all other match criteria are
     ignored.
