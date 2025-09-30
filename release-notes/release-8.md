# Packet Broker Release 8

Changes in this release

   * Replace the Intel SDE by a hybrid based on the open-source
     version of the SDE known as open-p4studio. The pure open-source
     version only supports the Tofino software emulation. Full support
     for the ASIC still requires access to the original SDE as well as
     the reference BSP. The hybrid version is essentially equivalent
     to SDE 9.13.4 and the same version number is used. open-p4studio
     uses the open-source Tofino backend provided by the p4c reference
     implementation maintained by the p4lang consortium.

   * bf-sde-nixpkgs is now based on nixpkgs 24.11

   * Add support for the Debian 13.1 kernel. The version of
     bf-sde-nixpkgs based on open-p4studio only supports kernels for
     Debian 12 and 13.

   * The ONIE installer is now based on Debian 13.1.

   * The Tofino2-based Asterfusion X732Q-T is added to the list of
     supported platforms.

   * The `stordis_bf6064x_t` is now only supported in BSP-less mode.
