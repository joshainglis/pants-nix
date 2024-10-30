{ makeRustPlatform
, rust-bin
, protobuf
, lib
, stdenv
, darwin
, libiconv

, src
, python
, version
}:
let
  # https://raw.githubusercontent.com/pantsbuild/pants/release_2.22.0/src/rust/engine/rust-toolchain
  rustVersion = "1.78.0";
  cargoLock = {
    # https://raw.githubusercontent.com/pantsbuild/pants/release_2.22.0/src/rust/engine/Cargo.lock
    lockFile = builtins.toPath "${src}/src/rust/engine/Cargo.lock";
    outputHashes = {
      "deepsize-0.2.0" = "sha256-E73xdzYfpJASps3yz6sjL48Kimy44F2LvxndWzgV3dU=";
      "deepsize_derive-0.1.2" = "sha256-E73xdzYfpJASps3yz6sjL48Kimy44F2LvxndWzgV3dU=";
      "globset-0.4.10" = "sha256-1ucpIHxISBqjvKBAea7o2wSddWiIQr6tBiInk4kg0P0=";
      "ignore-0.4.20" = "sha256-1ucpIHxISBqjvKBAea7o2wSddWiIQr6tBiInk4kg0P0=";
      "lmdb-rkv-0.14.0" = "sha256-yj0+3wRQkAyp5EYOe2WQeUt1D/3cXZK0XrH6qcxhaWw=";
      "lmdb-rkv-sys-0.11.0" = "sha256-c9lKJuE74Xp/sIwSFXFsl2EKffY3oC7Prnglt6p1Ah0=";
      "notify-5.0.0-pre.15" = "sha256-LG6e3dSIqQcHbNA/uYSVJwn/vgcAH0noHK4x3QQdqVI=";
      "prodash-16.0.0" = "sha256-Dkn4BmsF1SnSDAoqW5QkjdzGHEq41y7S20Q/DkRCpVQ=";
    };
  };

  cargo = rust-bin.stable.${rustVersion}.default;
  rustc = rust-bin.stable.${rustVersion}.default;
  rustPlatform = makeRustPlatform { inherit cargo rustc; };
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
