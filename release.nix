{ src ? { gitTag = "WIP"; }, buildInstaller ? false,
  buildRelease ? true, onieUsers ? {}, componentSuffix ? "" }:

with import ./. {
  inherit (src) gitTag;
  inherit onieUsers componentSuffix;
};

let
  optionalAttrs = cond: as: if cond then as else {};
in
(
  optionalAttrs buildRelease
    {
      ## The releases and releasesClosure derivations have the same
      ## closure. releasesClosure is used by the Hydra post-build hook
      ## to copy the closure to a separate binary cache.
      inherit release releaseClosure;
    }
) //
(
  optionalAttrs buildInstaller
    (
      (optionalAttrs buildRelease { inherit standaloneInstaller; }) //
      (optionalAttrs (builtins.match "release-[^-]+" src.gitTag != null)
        ## Build the ONIE installer for principal releases only
        { inherit onieInstaller; })
    )
)
