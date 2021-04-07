{ releases, versionFiles, nixProfile, lib, runCommand, closureInfo,
  coreutils, gnutar, gnused, rsync }:

let
  releaseInfo = release:
    let
      rootPaths = builtins.attrValues release;
      closure = closureInfo { inherit rootPaths; };
      modules = release.moduleWrapper.modules;
    in builtins.concatStringsSep ":" (
       [ modules.kernelID modules.release closure ]
       ++ rootPaths);
  releaseInfos = builtins.map releaseInfo (builtins.attrValues releases);
in runCommand "packet-broker-release-installer" {
  inherit releaseInfos;
} ''
  mkdir $out

  mkdir tmp
  cd tmp
  storePaths=
  for info in $releaseInfos; do
    IFS=:
    set -- $info
    kernelID=$1
    release=$2
    closureInfo=$3
    IFS=" "
    dest=$release/$kernelID
    mkdir -p $dest
    cp $closureInfo/{registration,store-paths} $dest
    storePaths="$storePaths $closureInfo/store-paths"
    shift 3
    echo "$@" >$dest/rootPaths
  done

  tar cf store-paths.tar $(cat $storePaths | sort | uniq | tr '\n' ' ')
  cp ${versionFiles.version + "/version"} version
  cp version $out
  cp ${versionFiles.version-id + "/version.id"} version.id
  echo ${nixProfile} >profile
  cp ${./install.sh} install.sh
  chmod a+x install.sh
  patchShebangs install.sh
  substituteInPlace install.sh --subst-var-by PATH \
    "${lib.strings.makeBinPath [ coreutils gnutar gnused rsync ]}"

  tar cf ../archive.tar *
  cd ..
  xz -T0 archive.tar
  cat ${./self-extractor.sh} archive.tar.xz >$out/installer.sh
  chmod a+x $out/installer.sh
  patchShebangs $out/installer.sh
''
