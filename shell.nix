{
  pkgs ? let
    rust_overlay = import (builtins.fetchTarball "https://github.com/oxalica/rust-overlay/archive/master.tar.gz");
  in
    import <nixpkgs> {
      overlays = [rust_overlay];
    },
}:
pkgs.mkShell {
  nativeBuildInputs = let
    pantspkgs = pkgs.callPackage ./. {};
  in [pantspkgs.pants-bin."release_2.20.1"];
}
