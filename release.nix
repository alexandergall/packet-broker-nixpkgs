{ src ? { gitTag = "WIP"; }, buildInstallers ? false }:

with import ./. { inherit (src) gitTag; };

## The releases and releasesClosure derivations have the same
## closure. releasesClosure is used by the Hydra post-build hook
## to copy the closure to a separate binary cache.
{
  inherit release releaseClosure;
} //
## Build the installers for releases only
(if ((builtins.match "release-[0-9]+" src.gitTag) != null) && buildInstallers then
  { inherit onieInstaller releaseInstaller; }
else
  {})
