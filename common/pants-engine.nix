{
  makeRustPlatform,
  rust-bin,
  protobuf,
  lib,
  stdenv,
  fetchFromGitHub,
  darwin,
  libiconv,
}: {
  src,
  version,
  hash,
  python,
  rustVersion,
  cargoLock,
  patches,
}: let
  cargo = rust-bin.stable.${rustVersion}.default;
  rustc = rust-bin.stable.${rustVersion}.default;
  rustPlatform = makeRustPlatform {inherit cargo rustc;};
  cargoDeps = rustPlatform.importCargoLock cargoLock;
  sourceRoot = "${src.name}/src/rust/engine";
in
  stdenv.mkDerivation {
    inherit version sourceRoot;
    pname = "pants-engine";

    src = src;

    cargoDeps = cargoDeps;

    nativeBuildInputs =
      [
        python
        protobuf
        rustPlatform.cargoSetupHook
      ]
      ++ lib.optionals stdenv.isDarwin [
        libiconv
        darwin.apple_sdk.frameworks.DiskArbitration
        darwin.apple_sdk.frameworks.Foundation
        darwin.apple_sdk.frameworks.IOKit
        darwin.apple_sdk.frameworks.CoreFoundation
      ];
    buildInputs = lib.optionals stdenv.isDarwin [
      darwin.apple_sdk.frameworks.Security
    ];

    buildPhase = ''
      export CARGO_BUILD_RUSTC=${rustc}/bin/rustc
      export RUSTFLAGS="--cfg tokio_unstable"

      ${lib.optionalString stdenv.isDarwin ''
        export LIBRARY_PATH=$LIBRARY_PATH:${darwin.libobjc}/lib
        export FRAMEWORK_SEARCH_PATHS="/System/Library/Frameworks"
        export MACOSX_DEPLOYMENT_TARGET=10.20
      ''}

      ${cargo}/bin/cargo build \
        --features=extension-module \
        --release \
        --package engine \
        --package client

      # Print the contents of the target directory
      echo "Contents of target/release after build:"
      ls -l target/release
    '';

    installPhase = ''
      echo "Contents of target/release:"
      ls -l target/release

      echo "Contents of target/release/deps:"
      ls -l target/release/deps

      mkdir -p $out/lib/
      mkdir -p $out/bin/

      # Try to find the library file
      ${
        if stdenv.isDarwin
        then ''
          if [ -f target/release/libengine.dylib ]; then
            cp target/release/libengine.dylib $out/lib/native_engine.so
          else
            echo "Error: Could not find libengine.dylib"
            exit 1
          fi
        ''
        else ''
          if [ -f target/release/libengine.so ]; then
            cp target/release/libengine.so $out/lib/native_engine.so
          else
            echo "Error: Could not find libengine.so"
            exit 1
          fi
        ''
      }

      # Copy the native client
      if [ -f target/release/pants ]; then
        cp target/release/pants $out/bin/native_client
      else
        echo "Error: Could not find pants executable"
        exit 1
      fi
    '';
  }
