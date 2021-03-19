{ bf-sde, src, version }:

bf-sde.buildP4Program {
  pname = "packet-broker";
  inherit version;
  p4Name = "packet_broker";
  inherit src;
  requiredKernelModule = "bf_kpkt";
}
