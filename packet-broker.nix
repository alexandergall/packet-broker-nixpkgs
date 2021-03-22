{ bf-sde, src, version }:

bf-sde.buildP4Program {
  pname = "packet-broker";
  inherit version src;
  p4Name = "packet_broker";
  requiredKernelModule = "bf_kpkt";
}
