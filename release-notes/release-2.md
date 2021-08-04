# Packet Broker Release 2

This release moves to `bf-sde-nixpkgs` version 10 to add
multi-platform support. Supported platforms are (Inventec is untested)

   * accton_wedge100bf_32x
   * accton_wedge100bf_32qs
   * accton_wedge100bf_65x
   * inventec_d5264q28b

Version 10 also provides utilities to build installers and a
generalized release manager.  This release makes use of these
utilities and removes the code that has been obsoleted by it.

The functionality of the Packet Broker itself remains unchanged but it
is now built for SDE 9.6.0.

