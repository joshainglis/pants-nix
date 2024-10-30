{pkgs}: {
  makePants = {
    version,
    hash,
    rustVersion,
    cargoLock,
    patches,
    pythonVersion ? "39",
  }: let
    pants-engine-func = pkgs.callPackage ./pants-engine.nix {};
    python = pkgs."python${pythonVersion}";
    pythonPackages = pkgs."python${pythonVersion}Packages";

    lib = pkgs.lib;

    src = pkgs.fetchFromGitHub {
      owner = "pantsbuild";
      repo = "pants";
      rev = "release_${version}";
      inherit hash;
    };

    pants-engine = pants-engine-func {inherit src version hash python rustVersion cargoLock patches;};
  in
    pythonPackages.buildPythonApplication {
      inherit version src;
      pname = "pants";
      pyproject = true;

      buildInputs = builtins.attrValues {
        inherit
          (pythonPackages)
          setuptools
          ;
      };

      # curl -L -O https://raw.githubusercontent.com/pantsbuild/pants/release_2.22.0/3rdparty/python/requirements.txt
      propagatedBuildInputs = builtins.attrValues {
        inherit
          (pythonPackages)
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

        echo ${version} > src/python/pants/_version/VERSION

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
}
