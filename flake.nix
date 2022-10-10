{
  description = "man-pages-ja";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # NAR hash differs between case-sensitive and case-insensitive systems after archiving.
    # So we store archived file itself.
    man-pages-ja = {
      type = "file";
      url = "https://linuxjm.osdn.jp/man-pages-ja-20220815.tar.gz";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, man-pages-ja }:
    {
      overlays.default = (final: prev: {
        jaman = self.packages.${prev.system}.default;
      });
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      rec {
        # Don't use pkgs.man; it has no config related to Japanese output
        packages.default = pkgs.stdenv.mkDerivation
          {
            name = "man-pages-ja";
            src = man-pages-ja;
            unpackCmd = "tar xvzf $curSrc";
            nativeBuildInputs = with pkgs; [ perl ];
            buildInputs = with pkgs; [ groff less coreutils less gzip bzip2 ];

            patchPhase = ''
              cp script/configure.perl{,.orig}
              export LANG=ja_JP.UTF-8
              cat script/configure.perl.orig | \
              sed \
                -e '/until/ i $ans = "y";' \
                -e "s#/usr/share/man#$out/share/man#" \
                -e 's/install -o $OWNER -g $GROUP/install/' \
                >script/configure.perl
            '';

            configurePhase = ''
              set +o pipefail
              yes "" | make config
            '';

            postInstall =
              let
                configFile = pkgs.writeTextFile {
                  name = "man.conf";
                  text = ''
                    TROFF   ${pkgs.groff}/bin/groff -Tps -mandoc -c
                    NROFF   ${pkgs.groff}/bin/groff -Wall -mtty-char -Tascii -mandoc -c
                    JNROFF  ${pkgs.groff}/bin/groff -Dutf8 -Tutf8 -mandoc -mja -E
                    EQN     ${pkgs.groff}/bin/eqn -Tps
                    NEQN    ${pkgs.groff}/bin/eqn -Tascii
                    JNEQN   ${pkgs.groff}/bin/eqn -Tutf8
                    TBL     ${pkgs.groff}/bin/tbl
                    REFER   ${pkgs.groff}/bin/refer
                    PIC     ${pkgs.groff}/bin/pic
                    PAGER   ${pkgs.less}/bin/less -isr
                    BROWSER ${pkgs.less}/bin/less -isr
                    CAT     ${pkgs.coreutils}/bin/cat

                    .gz  ${pkgs.gzip}/bin/gunzip -c
                    .bz2 ${pkgs.bzip2}/bin/bzip2 -cd
                  '';
                };
              in
              ''
                # The manpath executable looks up manpages from PATH. And this package won't
                # appear in PATH unless it has a /bin folder
                mkdir -p $out/bin

                cat <<EOF >"$out/bin/jaman"
                #!${pkgs.runtimeShell}
                MANPATH=$out/share/man LANG=ja_JP.UTF-8 \$(which man) "-C${configFile}" "\$@"
                EOF
                chmod +x "$out/bin/jaman"

                # makeWrapper /usr/bin/man "$out/bin/jaman" \
                #   --set MANPATH $out/share/man \
                #   --set LANG ja_JP.UTF-8 \
                #   --add-flags "-C$out/etc/man.conf"
              '';

            outputDocdev = "out";

            meta = {
              mainProgram = "jaman";
              priority = 30;
            };
          };
      });
}
