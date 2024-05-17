# The file is generated by:
#   $args
let
  lib = import ../lib.nix;

  version = "$version";
  hash = "$hash";

  # $rust_toolchain_url
  rustVersion = "$rust_version";
  cargoLock = {
    # $cargo_lock_url
    lockFile = ./Cargo.lock;
    outputHashes = {
      "console-0.15.7" = "sha256-EsUtBySVj2aoGOPBteDKCY7PCehJoqEJXpjOyQlpCf4=";
      "deepsize-0.2.0" = "sha256-E73xdzYfpJASps3yz6sjL48Kimy44F2LvxndWzgV3dU=";
      "globset-0.4.10" = "sha256-1ucpIHxISBqjvKBAea7o2wSddWiIQr6tBiInk4kg0P0=";
      "indicatif-0.17.7" = "sha256-GxQM+y5zL1KW5HmN9UcuS3xNNiZC8neMCyGIoOMleLs=";
      "lmdb-rkv-0.14.0" = "sha256-yj0+3wRQkAyp5EYOe2WQeUt1D/3cXZK0XrH6qcxhaWw=";
      "notify-5.0.0-pre.15" = "sha256-LG6e3dSIqQcHbNA/uYSVJwn/vgcAH0noHK4x3QQdqVI=";
      "prodash-16.0.0" = "sha256-Dkn4BmsF1SnSDAoqW5QkjdzGHEq41y7S20Q/DkRCpVQ=";
    };
  };
in
  lib.makePants {
    inherit version hash rustVersion cargoLock;
  }
