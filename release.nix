{ src ? { gitTag = "WIP"; }, buildInstaller ? false }:

with import ./. { inherit (src) gitTag; };

## The releases and releasesClosure derivations have the same
## closure. releasesClosure is used by the Hydra post-build hook
## to copy the closure to a separate binary cache.
{
  inherit release releaseClosure releaseInstaller;
} //
## Build the ONIE installer for principal releases only
(if ((builtins.match "release-[^-]+" src.gitTag) != null) && buildInstaller then
  { inherit onieInstaller; }
else
  {})
