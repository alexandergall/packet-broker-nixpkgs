let
  overlay = self: super:
    {
      net_snmp = super.net_snmp.overrideAttrs (oldAttrs: rec {
        configureFlags = oldAttrs.configureFlags ++
          [ "--with-perl-modules"
            "--with-persistent-directory=/var/lib/snmp"
          ];
        preConfigure = ''
          perlversion=$(perl -e 'use Config; print $Config{version};')
          perlarchname=$(perl -e 'use Config; print $Config{archname};')
          installFlags="INSTALLSITEARCH=$out/lib/perl5/site_perl/$perlversion/$perlarchname INSTALLARCHLIB=$out/lib/perl5/site_perl/$perlversion/$perlarchname INSTALLSITEMAN3DIR=$out/share/man/man3"
          # http://comments.gmane.org/gmane.network.net-snmp.user/32434
          substituteInPlace "man/Makefile.in" --replace 'grep -vE' '@EGREP@ -v'
        '';

        ## The standard package uses multiple outputs, but this fails
        ## when Perl modules are enabled.  This override should be fixed
        ## to support this.
        outputs = [ "out" ];

        ## Make sure libsnmp is available before building the Perl modules
        enableParallelBuilding = false;

        ## Skip multi-output logic
        postInstall = "true";
      });

      SNMPAgent = super.callPackage ./snmp {};
    };
in [ overlay ]
