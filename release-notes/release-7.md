# Packet Broker Release 7

Features

   * Support additional port configurations on Tofino2 (e.g. 100G on
     two SerDes lanes for 4x100 break-out mode)
   * Add support for Debian 12 kernels
   * Base ONIE installer on Debian 12.1
   * Move to SDE 9.13.0

Modules for Debian 10 kernels are no longer included in the standard
builds.

Bug-fixes

   * Port-mirroring was broken on SDE 9.12 and newer
   * release-manager: use explicit order of systemd services during
     profile activation to preserve service dependencies
