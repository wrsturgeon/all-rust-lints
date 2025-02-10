{
  outputs =
    { self }:
    {
      __functor =
        self: pkgs: rust-toolchain:
        pkgs.stdenvNoCC.mkDerivation {
          name = "all-lints";
          src = builtins.path {
            filter = _: _: false;
            name = "no-src";
            path = ./.;
          };
          buildPhase = ":";
          installPhase =
            let
              binaries = builtins.mapAttrs (name: from: "${from}/bin/${name}") {
                cut = pkgs.coreutils;
                grep = pkgs.gnugrep;
                head = pkgs.coreutils;
                sort = pkgs.coreutils;
                tail = pkgs.coreutils;
                tr = pkgs.coreutils;
              };
              clippy-help-cmd = "cargo clippy --no-deps -- -Zunstable-options -W help > \${out}/clippy-help.txt 2>&1";
              check-empty = file: ''
                if [ ! -s "${file}" ]
                then
                  echo '***** ERROR: empty `${file}` *****'
                  for f in $(find . -name '*.txt')
                  do
                    echo
                    echo 'contents of `'"''${f}"'`:'
                    cat "''${f}"
                  done
                  exit 1
                fi
              '';
            in
            with binaries;
            ''
              set -eu
              set -o pipefail

              mkdir -p src
              echo ${pkgs.lib.strings.escapeShellArg ''
                cargo-features = [ "edition2024" ]

                [package]
                name = "all-lints"
                version = "0.1.0"
                edition = "2024"
              ''} > Cargo.toml
              touch src/lib.rs

              set +e
              mkdir -p ''${out}
              ${clippy-help-cmd}
              if [ "$?" -ne '0' ]
              then
                echo '***** ERROR (${clippy-help-cmd}) *****'
                echo 'dump:'
                cat ''${out}/clippy-help.txt
                exit 1
              fi

              mkdir clippy
              cd clippy
              cat ''${out}/clippy-help.txt | ${grep} -A9999 -m1 -e '^Lint checks loaded by this crate:$' > after-lint-checks.txt
              ${check-empty "after-lint-checks.txt"}
              cat after-lint-checks.txt | ${grep} -A9999 -m1 -e '-------' > after-line.txt
              ${check-empty "after-line.txt"}
              rm after-lint-checks.txt
              cat after-line.txt | ${tail} -n+2 > after-two-more.txt
              ${check-empty "after-two-more.txt"}
              rm after-line.txt
              cat after-two-more.txt | ${grep} -B9999 -m1 -e '^$' > before-blank-line.txt
              ${check-empty "before-blank-line.txt"}
              rm after-two-more.txt
              cat before-blank-line.txt | ${head} -n-1 > before-one-more.txt
              ${check-empty "before-one-more.txt"}
              rm before-blank-line.txt
              cat before-one-more.txt | ${cut} -d ':' -f 3- > after-colon.txt
              ${check-empty "after-colon.txt"}
              rm before-one-more.txt
              cat after-colon.txt | ${tr} -s ' ' > single-space.txt
              ${check-empty "single-space.txt"}
              rm after-colon.txt
              cat single-space.txt | ${cut} -d ' ' -f -2 > first-two-columns.txt
              ${check-empty "first-two-columns.txt"}
              rm single-space.txt
              cat first-two-columns.txt | ${sort} > ''${out}/sorted-clippy.txt
              ${check-empty "\${out}/sorted-clippy.txt"}
              rm first-two-columns.txt
              if [ ! -s ''${out}/sorted-clippy.txt ]
              then
                echo
                echo '*******************************************'
                echo '***** ERROR: no `clippy` lints found! *****'
                echo '*******************************************'
                echo
                for f in $(find . -name '*.txt')
                do
                  echo
                  echo 'contents of `'"''${f}"'`:'
                  cat "''${f}"
                done
                exit 1
              fi
              cd ..

              mkdir rustc
              cd rustc
              cat ''${out}/clippy-help.txt | ${grep} -A9999 -m1 -e '^Lint checks provided by rustc:$' > after-lint-checks.txt
              ${check-empty "after-lint-checks.txt"}
              cat after-lint-checks.txt | ${grep} -A9999 -m1 -e '-------' > after-line.txt
              ${check-empty "after-line.txt"}
              rm after-lint-checks.txt
              cat after-line.txt | ${tail} -n+2 > after-two-more.txt
              ${check-empty "after-two-more.txt"}
              rm after-line.txt
              cat after-two-more.txt | ${grep} -B9999 -m1 -e '^$' > before-blank-line.txt
              ${check-empty "before-blank-line.txt"}
              rm after-two-more.txt
              cat before-blank-line.txt | ${head} -n-1 > before-one-more.txt
              ${check-empty "before-one-more.txt"}
              rm before-blank-line.txt
              cat before-one-more.txt | ${tr} -s ' ' > single-space.txt
              ${check-empty "single-space.txt"}
              rm before-one-more.txt
              cat single-space.txt | sed -e 's/^[[:space:]]*//' > without-initial-space.txt
              ${check-empty "without-initial-space.txt"}
              rm single-space.txt
              cat without-initial-space.txt | ${cut} -d ' ' -f -2 > first-two-columns.txt
              ${check-empty "first-two-columns.txt"}
              rm without-initial-space.txt
              cat first-two-columns.txt | ${sort} > ''${out}/sorted-rustc.txt
              ${check-empty "\${out}/sorted-rustc.txt"}
              rm first-two-columns.txt
              if [ ! -s ''${out}/sorted-rustc.txt ]
              then
                echo
                echo '*******************************************'
                echo '***** ERROR: no `rustc` lints found! *****'
                echo '*******************************************'
                echo
                for f in $(find . -name '*.txt')
                do
                  echo
                  echo 'contents of `'"''${f}"'`:'
                  cat "''${f}"
                done
                exit 1
              fi
              cd ..

              set -e

              echo '{' > ''${out}/clippy.nix
              while read line
              do
                echo '  '$(echo "''${line}" | cut -d ' ' -f 1)' = "'$(echo "''${line}" | cut -d ' ' -f 2)'";' >> ''${out}/clippy.nix
              done < ''${out}/sorted-clippy.txt
              echo '}' >> ''${out}/clippy.nix

              echo '{' > ''${out}/rustc.nix
              while read line
              do
                echo '  '$(echo "''${line}" | cut -d ' ' -f 1)' = "'$(echo "''${line}" | cut -d ' ' -f 2)'";' >> ''${out}/rustc.nix
              done < ''${out}/sorted-rustc.txt
              echo '}' >> ''${out}/rustc.nix
            '';
          nativeBuildInputs = [ rust-toolchain ];
        };
    };
}
