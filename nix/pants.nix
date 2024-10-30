{ inputs, self, ... }: {
  perSystem = { config, pkgs, lib, system, ... }: {
    options.pants = {
      version = pkgs.lib.mkOption {
        default = "2.22.0";
        type = lib.types.str;
        description = "Pants version to use";
      };
      hash = pkgs.lib.mkOption {
        default = "sha256-1dmT41gmwgQz4gL2Ga51r1e48zqRSWXzWXORrH5ztag=";
        type = lib.types.str;
        description = "Pants source hash";
      };
      python = pkgs.lib.mkOption {
        default = pkgs.python39;
        type = pkgs.lib.types.package;
        description = "Python interpreter to use";
      };
      package = pkgs.lib.mkOption {
        internal = true;
        readOnly = true;
        type = pkgs.lib.types.package;
        description = "Pants package";
      };
    };
    config.pants =
      let
        src = pkgs.fetchFromGitHub {
          owner = "pantsbuild";
          repo = "pants";
          rev = "release_${config.pants.version}";
          hash = config.pants.hash;
        };

        patches = [
          ./patches/patch-process-manager.txt
          ./patches/patch-jar-tool.txt
          ./patches/patch-coursier-fetch.txt
          ./patches/patch-process.txt
          ./patches/patch-jdk-sh.txt
          ./patches/patch-process-extra-env-2.22.txt
        ];

        pants-engine = pkgs.callPackage ./pants-engine.nix {
          inherit src;
          version = config.pants.version;
          python = config.pants.python;
        };

        pythonPackages = config.pants.python.pkgs;
        pants_app = pythonPackages.buildPythonApplication {
          inherit src;
          pname = "pants";
          version = config.pants.version;
          pyproject = true;

          buildInputs = builtins.attrValues {
            inherit (pythonPackages)
              setuptools
              ;
          };

          # curl -L -O https://raw.githubusercontent.com/pantsbuild/pants/release_2.22.0/3rdparty/python/requirements.txt
          propagatedBuildInputs = builtins.attrValues {
            inherit (pythonPackages)
              ansicolors
              chevron
              fasteners
              freezegun
              ijson
              packaging
              pex
              psutil
              pytest
              python-lsp-jsonrpc
              pyyaml
              requests
              setproctitle
              setuptools
              toml
              types-freezegun
              types-pyyaml
              types-requests
              types-setuptools
              types-toml
              typing-extensions
              node-semver
              ;
          };

          # https://github.com/pantsbuild/pants/blob/release_2.22.0/src/python/pants/BUILD#L27-L39
          configurePhase = ''
            cat > setup.py << EOF
            from setuptools import setup, Extension

            setup(
                ext_modules=[Extension(name="dummy_twAH5rHkMN", sources=[])],
            )
            EOF

            cat > pyproject.toml << EOF
            [build-system]
            requires = ["setuptools"]
            build-backend = "setuptools.build_meta"

            [project]
            name = "pants"
            version = "$version"
            requires-python = "==3.9.*"
            dependencies = [
              "packaging",
            ]

            [tool.setuptools]
            include-package-data = true

            [tool.setuptools.packages.find]
            where = ["src/python"]
            include = ["pants", "pants.*"]
            namespaces = false

            [project.scripts]
            pants = "pants.bin.pants_loader:main"

            EOF

            echo ${config.pants.version} > src/python/pants/_version/VERSION

            cat > MANIFEST.in << EOF
            include src/python/pants/_version/VERSION
            include src/python/pants/engine/internals/native_engine.so
            include src/python/pants/bin/native_client
            recursive-include src/python/pants *.lock *.java *.scala *.lockfile.txt
            EOF

            find src/python -type d -exec bash -c "if [ -n \"$ls {}/*.py\" ]; then touch {}/__init__.py; fi" \;
          '';

          prePatch =
            lib.strings.concatMapStrings
              (patch_path: "patch -p1 --batch -u -i ${patch_path}\n")
              patches;

          preBuild = ''
            # https://github.com/pantsbuild/pants/blob/release_2.22.0/src/python/pants/engine/internals/BUILD#L28
            cp ${pants-engine}/lib/native_engine.so src/python/pants/engine/internals/

            # https://github.com/pantsbuild/pants/blob/release_2.22.0/build-support/bin/rust/bootstrap_code.sh#L34
            cp ${pants-engine}/bin/native_client src/python/pants/bin/

            export PREV_TMPDIR=$TMPDIR
            rm -rf build dist *.egg-info
            export TMPDIR=$(mktemp -d)

            mkdir -p $TMPDIR
            chmod 1777 $TMPDIR
          '';

          postInstall = ''
            wrapProgram "$out/bin/pants" \
              --set NO_SCIE_WARNING 1 \
              --set PYTHONWARNINGS "ignore::DeprecationWarning:pkg_resources,ignore::DeprecationWarning:pants.init.options_initializer" \
              --run "if [ -f .pants.bootstrap ]; then . .pants.bootstrap; fi"

            rm -rf $TMPDIR
            export TMPDIR=$PREV_TMPDIR
          '';
        };
      in
      {
        package = pants_app;
      };
  };
}
