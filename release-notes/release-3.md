# Packet Broker Release 3

This release fixes a bug in release 2 that prevented the system to
work properly with deployments using a restricted binary cache.  The
bug caused all types of `--install` options of the release-manager to
fail on these systems.
