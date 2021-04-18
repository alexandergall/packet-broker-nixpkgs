# packet-broker-nixpkgs

Packaging of the [P4 Packet
Broker](https://github.com/alexandergall/packet-broker) for the Nix
package manager.

## Overview

The set of packages produced by this Nix expression provides a
complete deployment of the Packet Broker as an appliance on systems
based on the Tofino packet-processing ASIC.  It includes an ONIE
installer for the initial setup and a tool for managing releases on a
running system.

Currently, the base OS provided by the ONIE installer is a basic
version of Debian 10.9 combined with an installation of the [Nix
package manager](https://nixos.org/manual/nixpkgs/stable/).  While
Debian is used to manage the host itself, all components of the Packet
Broker service are provided by Nix. This repository depends on the
[Nix packaging of the Tofino
SDE](https://github.com/alexandergall/bf-sde-nixpkgs).  The main
advantages of using this framework are

   * Declarative style of package management: all properties and
     dependencies of software components are declared explicitly in a
     high-level description of the desired system
   * Precise dependency tracking: dependencies include all properties
     of the dependent package, not just its name and version
   * High level of reproducibility: given the declarative description
     of the system, anyone can reproduce the packages exactly
     (e.g. without any random dependencies on the environment of the
     build host)
   * Isolation from the package manager of the base OS: [except for
     the kernel](#kernelSupport), the Nix packages are completely
     self-contained and do not depend on any packages of the host's
     native package manager

As a result, the system provides for very reliable deployments of the
service, avoiding many potential problems that are inherent with
traditional package managers.

The built-in release manager performs all interactions with the Nix
package manager on behalf of the user.  While no knowledge of Nix is
required to work with the system, the curious user is encouraged to
learn about this great tool as the key to reliable service deployment
:)

In principle, it is very easy to [build any of the components
yourself](#building). In fact, having everything defined in terms of
Nix expressions makes it not only easy but also reproducible on any
Linux-based system irrespective of the distribution being used,
i.e. no more hunting for an ever changing list of dependencies before
you can even try to build a project.

However, building everything from scratch requires access to the
Tofino SDE, which is currently only possible by entering an NDA with
Intel.  But Intel also grants the right to distribute certain parts of
the SDE as pre-built packages for binary deployments. For the Packet
Broker project, those packages are publicly available from a
repository hosted at `p4.cache.nix.net.switch.ch`. The [ONIE
installer](#ONIE) comes with this repository pre-configured.

## Supported Platforms

The packages only support Tofino ASICs of the first generation at this
time.  Currently, the only verified platform is

   * `accton-wedge100bf-32x`

The system should also work on the 65x-variant
(`accton-wedge100bf-65x`) but has not been verified.

Other platforms that don't have external gearboxes to support
non-native port configurations are also expected to work, with the
possible exception of the management Ethernet and CDC-Ethernet (used
for communication between the host and the BMC) interfaces due to
different configurations of the PCIe bus.

## <a name="ONIE"></a>Initial Setup using the Pre-Built ONIE Installer

Devices like the `accton-wedge100bf-32x` usually come with a
pre-installed ONIE.  ONIE-compatible installers for releases of the
Packet Broker are [available for
download](http://hydra.nix.net.switch.ch/packet-broker/releases/). To
perform an installation, boot the system into "ONIE install
mode". Then copy the URL of the `onie-installer.bin` file for the
desired release and execute `onie-nos-install <URL>` at the `ONIE`
prompt. For example

```
ONIE# onie-nos-install http://hydra.nix.net.switch.ch/packet-broker/releases/1/onie-installer.bin
```

Note well: **This procedure destroys all partitions beyond partitions
1 and 2**. The EFI and ONIE partitions are preserved and the GRUB boot
loader of the Debian system includes an entry to chain-load the ONIE
boot loader to make it easy to perform ONIE operations after an image
has been installed.

## Configuration and Usage

After the initial setup, the system has the following properties

   * No regular user account
   * Root access without password on the serial console only
   * The management interface is set up to perform DHCP
   * An empty Packet Broker configuration in
     `/etc/packet-broker/config.json`
   * A basic `snmpd` configuration in `/etc/snmp/snmpd.conf`, which
     does not allow any non-local connections
   * Pre-built Nix packages are fetched from
     http://p4.cache.nix.net.switch.ch/ (via `/etc/nix/nix.conf`)

The OS can be freely configured as a regular Debian system. Changes to
the Debian packages will not impact the Packet Broker service in any
way, except for a change of kernel.

### `systemd` services

The Packet Broker implements the following `systemd` services.

#### `packet-broker.service`

This is the main service unit, which runs the `bf_switchd` daemon to
execute the P4 program.

#### `packet-broker-configd.service`

This service units runs the control-plane process `configd` as a
daemon. It is automatically started and stopped with the main
`packet-broker.service`.

#### `snmpd.service`

This service runs an instance of the `net-snmp` SNMP daemon. It uses
the AgentX protocol to communicate with `snabb-snmp-agent.service`,
which provides the MIB for the interfaces controlled by the packet
broker.

#### `snabb-snmp-agent.service`

To make interface counters available via SNMP, the services `snmpd`
and `snabb-snmp-agent` must also be enabled (which is the default).
This also requires the configuration of access rules (SNMP community
strings and access-lists) in `/etc/snmp/snmpd.conf`.

### Packet Broker Configuration

To configure the Packet Broker, edit `/etc/packet-broker/config.json`
and execute either

```
$ brokerctl reload
```

or

```
# systemctl reload packet-broker-configd
```

For a complete description of the available options for `config.json`
and the `brokerctl` command please refer to the [Packet Broker
documentation](https://github.com/alexandergall/packet-broker/blob/master/README.md)

### `bf_switchd` CLI

Use the `bfshell` command to enter the CLI provided by the
`bf_switchd` daemon.  Please refer to the documentation provided by
Intel on how to use the CLI.

## Release Management

The maintenance of releases of the Packet Broker service is performed
with a separate utility called `release-manager`, which is part of the
release itself.

Any number of releases can be installed on the system
concurrently. Only one of the releases is active at any given time and
it is possible to switch between any of the installed releases
arbitrarily. The following section describes how versioning of
releases is defined for the Packet Broker project.

### <a name="versioning"></a>Versioning

The repository uses the `master` branch for development of the
upcoming release. The actual version number is defined as the
`version` attribute in `default.nix`. Currently, the version is chosen
to be an integer without any additional structure.  However, the only
assumption made by the `release-manager` is that it is unique for each
release and doesn't contain any hyphens.

At the time of release of version `<v>` (the current value of the
`version` attribute), the maintainer performs the following tasks

   * Tag the commit on the `master` branch
      ```
      git tag -a -m "Release <v>" release-<v>
      git push origin release-<v>
      ```
   * Create a release branch with the version `<v>` as name
      ```
      git checkout -b <v>
      git push origin <v>
      ```
   * On `master`
      * Add a Hydra CI job for `release-<v>` to `spec.json`
      * bump the version in `default.nix` to `<v+1>`
      * add `release-notes/release-<v+1>.md`
      * `git commit -m "Release <v+1> beta`

Development of the next release with version `<v+1>` takes place on
`master`. Updates to release `<v>` are maintained on the branch
`<v>`. This is mainly intended for fixes of bugs and security issues.

The branch-off points carrying the Git tags `release-<v>` are called
_principal releases_.  All other commits are either updates of a
principal release (if they are on a release branch) or pre-releases of
the next version (if they are on `master`).

The `git describe` mechanism is used to uniquely identify all commits
in relation to the principal release from which they are derived.  We
refer to this identifier as `gitTag` throughout this documentation and
in the `release-manager` utility.  The `gitTag` expresses the
"distance" of the commit to the closest annotated tag reachable from
the commit in the form `<tag>-<n>-g<commit>`, where `<tag>` is the
name of the annotated tag, `<n>` is the number of commits following
the tagged commit and `<commit>` is the abbreviated commit itself.

By convention, `<tag>` is always of the form `release-<v>` in this
repository. With this, every commit belongs to one of two classes:

   1. `<gitTag>` is of the form `release-<v>`. This marks the principal
      release of version `<v>`.
   2. `<gitTag>` is of the form `release-<v>-<n>-g<abbrev>`. This
      identifies the release as an update of the principal release
      `<v>` or a pre-release of the next release.

If we also take the value of the `version` attribute into account, the
commits in the second class can be further distinguished:

   * `<v>` is equal to `version`. Such a commit is an update of a
     principal release on a release branch.
   * `<v>` is equel to `version+1`. Such a commit is a pre-release of
     release `version+1` on the `master` branch.

### Release Contents

A release of the Packet Broker service is comprised of the following
components

   * `packet-broker`. A command which starts the `bf_switchd` process
     provided by the Tofino SDE with the compiled [`packet-broker` P4
     program](https://github.com/alexandergall/packet-broker/blob/master/packet_broker.p4).
   * `packet-broker-module-wrapper`. A wrapper script around
     `packet-broker`, which loads the appropriate kernel module before
     starting `bf_switchd`.
   * `configd`. A command that starts the
     [control-plane](https://github.com/alexandergall/packet-broker/tree/master/control-plane)
     process, which reads the configuration file and programs the
     match-action-units on the ASIC accordingly. It also communicates
     with the `brokerctl` CLI utility.
   * `systemd` service units. A set of unit files for the
     `packet-broker`, `packet-broker-configd`, `snmpd` and
     `snabb-snmp-agent` services.
   * `bf-utils`. A package provided by the SDE which includes the
     `bfshell` command used to start a CLI session with the running
     `bf_switchd` process.
   * `release-manager`. A command to manage releases of the service.
   * `version`. A file containing the version information of the
     release.

Each of these components is a package by itself in the sense of the
Nix package manager.  In other words, the release is a collection of
packages which is treated as a unit by the release manager.

The `version` file contains the version and gitTag as a string of the
form `<version>:<gitTag>`.

### <a name="kernelSupport"></a>Kernel Support

The SDE includes a set of kernel modules needed by the `bf_switchd`
process.  Every kernel for which these modules should be built must be
explicitly supported by the SDE package. The [list of supported
kernels](https://github.com/alexandergall/bf-sde-nixpkgs/blob/master/bf-sde/kernels/default.nix)
is part of the SDE package definition.

A release of the Packet Broker includes the modules for all supported
kernels.  At the time of installation on a specific target, only the
modules that match the local kernel will be installed.  This implies
that a release cannot be installed on an unsupported kernel.

As a result, only a subset of the components contained in the release
is installed on any given target. This subset is referred to as a
_slice_ of the release. By definition, all slices have the same
version information. Since it is possible to install multiple slices
on a system to support kernel upgrades or multi-kernel configurations,
it is necessary to distinguish them from each other. For this purpose,
each slice includes a file called `slice`, containing the identifier
of the kernel in the form `<kernelID>:<kernelRelease>`.

The `<kernelID>` is already a unique identifier for the
kernel. Technically, it is the name of the attribute in a set that
defines the [properties of every supported
kernel](https://github.com/alexandergall/bf-sde-nixpkgs/blob/master/bf-sde/kernels/default.nix)
in the `bf-sde-nixpkgs` Nix expression, e.g. `Debian10_8` or
`ONL9`. Each such definition includes the exact kernel release
identifier of that kernel, which is the result of running `uname -r`
on a running instance of the kernel.

The kernel release string is included in the slice identifier as the
`<kernelRelease>` string.  The sole purpose of this is to make it
explicit to the administrator for which kernel a release has been
built when looking at an installed instance. For example, the
following one-to-one correspondence holds for the kernels with
`kernelID` `Debian10_8` and `Debian10_9`

   * `<kernelID>` = `Debian10_8` <=> `<kernelRelease>` = 4.19.0-14-amd64
   * `<kernelID>` = `Debian10_9` <=> `<kernelRelease>` = 4.19.0-16-amd64

### Using the Release Manager

All manipulations of releases are performed with the `release-manager`
CLI tool which is part of every release. It supports the following
options

   * `--list-installed`
   * `--list-available`
   * `--install-release <version>`
   * `--install-git <git-commit>`
   * `--update-install <version>`
   * `--untinstall-generation <gen>`
   * `--activate-current`
   * `--deactivate-current`
   * `--switch-to-generation <gen>`
   * `--cleanup`

The `--install-*` options require network access to various sites
(Github, the generic Nix package cache and the package repository for
pre-built components of the Packet Broker).  In case generic network
access by the device is prohibited by security policies or technical
limitations, releases can also be deployed by a [standalone
installer](#standaloneInstaller) which does not require any network
access at all as detailed in the next chapter. All other options of
`release-manager` do not requrie network access.

#### `--list-installed`

This option lists the currently installed releases

```
$ release-manager --list-installed
Generation Current Release Git ID       KernelID       Kernel Release            Install date
-------------------------------------------------------------------------------------------------------------------
         1 *       1       release-1    Debian11       5.10.0-5-amd64            2021-04-14 08:00:16.832902563 +0000
```

The generation is a monotonically increasing integer that uniquely
identifies the installed releases.  Every new release installed either
by `release-manager` or a standalone installer is assigned a new
generation number which is equal to the highest generation in the list
plus one.

There can be any number of releases installed at the same time, but
only one of them can provide the Packet Broker service at any given
time as detailed in the description of the `--activate-current` and
`--deactivate-current` options. This release is said to be the
_current_ release and is marked by a `*` in the "Current" column of
the list.

The "Release" and "Git ID" columns display the [versioning
information](#versioning).

As explained in the section on [kernel support](#kernelSupport), a
full relase contains the modules for all supported kernels, but only
the modules for the local kernel are installed on any given system.
That subset of the full release is called a _slice_.  The "Kernel ID"
and "Kernel Release" colummns in the list of installed releases
identify the installed slice. Note that it is possible to install
multiple slices of the same release to support upgrades of the kernel
and multi-kernel setups.

Finally, the "Install Date" Column gives the time and date at which
the release slice was installed.

Implementation note: the release-manager uses the
[profiles](https://nixos.org/manual/nix/unstable/package-management/profiles.html)
feature of the Nix package manager to keep track of installed
releases. The notion of generations is taken straight from the
underlying Nix profile.  The profile used for the Package Manager is
located in `/nix/var/nix/profiles/packet-broker`.

#### `--list-available`

This option requires access to `github.com`. It uses the Github API to
query the set of tags of the `packet-broker-nixpkgs` repository and
looks for tags of the form `release-<v>`.  For each such tag it prints
a line to inform the user that release version `<v>` is available for
installation.  It will also indicate whether there are any slices of
that release already installed on the system

```
$ release-manager --list-available
INFO: Checking for release tags of https://github.com//alexandergall/packet-broker-nixpkgs

Version  Status
-----------------------------------------------
       1  Installed in generaton(s) 2
```

#### `--install-release <version>`

This option requires network access to `github.com`, `nixos.org` and
`p4.cache.nix.net.switch.ch`. Given one of the version numbers
reported by `--list-available`, this option downloads the definition
of the release expressed as a Nix expression, fetches the pre-built
packages required by it and installs the slice for the currently
running kernel.

This operation is completely safe, reversible and does not affect the
running service.  It only installs the packages and makes them
available for activation with the `--switch-to-generation` option.

Due to the nature of Nix, packages are never overwritten or changed in
any way after installation.  This is what makes concurrent versions
without any danger of conflicts possible.

The command will fail if the release is already present on the system.

#### `--install-git <git-commit>`

This option requires the same network access as `--install-release`.
While `--install-release` is restricted to installing principal
releases, `--install-git` allows the installation of an arbitrary
commit. It fetches the `packet-broker-nixpkgs` repository using a Git
"remote" called `origin` and checks out the commit with `git reset
--hard`. `<git-commit>` can be any identifier of a commit (i.e. a
"commit-ish" in Git terminology).  For example, to install the current
tip of the branch `1`, one woud use

```
$ release-manager --install-git origin/1
```

This is equivalent to using the option `--update-release 1`.

### `--update-release <version>`

This option is a shortcut for

```
$ release-manager --install-git origin/1
```

to update a release to the most recent commit on the release branch.

#### `--untinstall-generation <gen>`

This option removes the generation denoted by `<gen>` from the list of
installed releases. It doesn't actually remove any packages unless you
run `--cleanup` as well, but it makes the release unavailable for
activation.

#### `--activate-current`

Mere installation of a release does not instantiate the Packet Broker
service automatically. This only happens after _activation_.
Activation performs the following operations for the currently active
generation

   * Create symbolic links to the `systemd` service units in
     `/etc/systemd/system`
   * Enable the services
      * `systemctl enable packet-broker packet-broker-configd snmp snabb-snmp-agent`
   * Call `systemctl daemon-reload`
   * Create directories (if they don't exist already)
      * `/etc/packet-broker`
      * `/etc/snmp`
      * `/var/lib/snmp`
   * Install the files (overwriting existing ones)
      * `/etc/packet-broker/schema.json`
      * `/etc/snmp/ifindex`
      * `/var/lib/snmp/interface.conf`
   * Install defaults (does not overwrite existing files)
      * `/etc/packet-broker/config.json`
      * `/etc/snmp/snmpd.conf`
   * Create
      * `/etc/profile.d/packet-broker.sh`
   * Start the services
      * `systemctl start packet-broker`
      * `systemctl start snmpd`

#### `--deactivate-current`

This performs the reverse of `--activate-current`

   * Stop the services
      * `systemctl stop snmpd packet-broker`
   * Disable the services
      * `systemctl disable packet-broker packet-broker-configd snmp
        snabb-snmp-agent`
   * Unload SDE kernel modules

#### `--switch-to-generation <gen>`

This option is used to switch the service from the currently active
release to another in the list of installed releases.  The argument to
the option must be one of the generations displayed with
`--list-installed`.  The switch is done by first performing a
`--deactivate-current` with the `release-manager` of the current
release (this stops the running instance). Then the current release is
switched to the specified generation. The release is activated by
calling the `release-manager` of the new release with the
`--activate-current` option, which re-starts the service with the new
release.  Note that this also causes the kernel modules of the old
release to be unloaded and re-loaded from the new release.

#### `--cleanup`

The Nix package manager doesn't delete any packages automatically.
Instead, it uses a garbage collector to keep track of packages which
are "in use" (also called _live_).  All packages needed by one of the
installed releases are automatically considered to be live and never
removed.  However, if a release has been uninstalled with
`--uninstall-generation`, it is no longer considered live and subject
to removal.

The `--cleanup` option deletes all packages which are not live. This
can be used to free up disk space if needed.

Implementation note: this option essentially calls the
`nix-collect-garbage` utility, which can also be called directly by
the user.

### <a name="standaloneInstaller"></a>Standalone Release Installer

The installation functionality of the `release-manager` requires that
the device has access to the Internet to download various
components. It is fairly common that network operators have more or
less severe restrictions on the extent to which this is possible,
mostly due to security concerns but also due to technical reasons
(e.g. using non-routable addresses for the management ports).

To overcome this limitation, the Packet Broker can also be installed
through a self-contained installer, which doesn't need any network
access once it is copied to the target device.  This installer consist
of a single self-extracting archive.

Installers for all releases can be downloaded from the [same
site as the ONIE
installer](http://hydra.nix.net.switch.ch/packet-broker/releases/). The
files are named `packet-broker-<gitTag>-install.sh` and are
accompanied by a file with the extension `.sha256` containing the
SHA256 hash for verification.

Once the installer has been copied to the device, execute it as root,
e.g.

```
# $ sudo packet-broker-release-1-install.sh
Unpacking archive
INFO: Installing packet broker release 1 (Id: 1:WIP) for kernel 5.10.0-5-amd64 in /nix/var/nix/profiles/packet-broker
INFO: Copying store paths
INFO: Registering paths in DB
INFO: Installing the service in /nix/var/nix/profiles/packet-broker
INFO: Installation completed
INFO: Use "release-manager --switch-to-generation 3" to switch to this release
Currently installed releases:
Generation Current Release Git Tag      KernelID       Kernel Release      Install date
-------------------------------------------------------------------------------------------------------------------
         2 *       1       release-1    Debian11       5.10.0-5-amd64      2021-04-14 08:00:16.832902563 +0000
         3         1       WIP          Debian11       5.10.0-5-amd64      2021-04-14 15:50:44.125809762 +0000
```

The result is exactly the same as with the `--install-{release,git}`
options of `release-manager`, i.e. the releases installed with a
standalone installer can be manipulated with `release-manager` like
those that were installed with the native method.

## <a name="building"></a>Building

### From Scratch

To build everything from scratch you need access to the Tofino SDE
from Intel (currently available only by signing an NDA). You also need
an installation of the Nix package manager on any Linux distribution,
provided it supports the `x86-64` architecture.

For details how to set up your build system please refer to the first
section of the [documentation of the SDE Nix
package](https://github.com/alexandergall/bf-sde-nixpkgs#bf-sde-nixpkgs). You
need to perform the steps

   * [Install the Nix package manager in multi-user
     mode](https://github.com/alexandergall/bf-sde-nixpkgs#install-the-nix-package-manager-in-multi-user-mode)
   * [Fetch and verify source
     archives](https://github.com/alexandergall/bf-sde-nixpkgs#fetch-and-verify-source-archives)
     for version 9.4.0 of the SDE
   * [Add archives to the Nix
     store](https://github.com/alexandergall/bf-sde-nixpkgs#add-archives-to-the-nix-store)

Then clone this repository

```
$ git clone https://github.com/alexandergall/packet-broker-nixpkgs.git
```

Check out the desried release, e.g.

```
$ cd packet-broker-nixpkgs
$ git checkout release-1
```

To build the ONIE installer, execute

```
$ nix-build -A onieInstaller
```

This will build everything from the SDE source code and take between
30 and 60 minutes, depending on your build host.

To build the standalone installer:

```
$ nix-build -A releaseInstaller
```

The result is a Nix _derivation_, essentially a directory in
`/nix/store` with a weird name. For example

```
$ nix-build -A onieInstaller
/nix/store/a6l2af11hipk8v0h002hcz3c1q9lzyyj-onie-installer-debian-buster
```

The installer itself is the file `onie-installer.bin` located in that
directory.

### From pre-built Packages

The [public
repository](http://hydra.nix.net.switch.ch/packet-broker/releases/)
only provides installers for "principal" releases (i.e. for those
commits that carry a `release-<v>` tag). Installers for non-principal
releases can be be built from the pre-built packages from
`p4.cache.nix.net.switch.ch` without access to the source SDE packages.

For this, just make sure that the following lines are part of
`/etc/nix/nix.conf` (execute `systemctl restart nix-daemon` after
modifying this file):

```
extra-substituters = https://cache.nixos.org http://p4.cache.nix.net.switch.ch
trusted-substituters = https://cache.nixos.org http://p4.cache.nix.net.switch.ch 
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= p4.cache.nix.net.switch.ch:cR3VMGz/gdZIdBIaUuh42clnVi5OS1McaiJwFTn5X5g=
```

You can then proceed to build the `onieInstaller` and
`releaseInstaller` packages as described in the previous chapter.
