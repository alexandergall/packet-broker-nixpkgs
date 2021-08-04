{ bf-sde, src, version, platform }:

bf-sde.buildP4Program {
  pname = "packet-broker";
  inherit version src platform;
  p4Name = "packet_broker";
  requiredKernelModule = "bf_kpkt";
}
