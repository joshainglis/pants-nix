{
  description = "Pants build system Nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    rust-overlay,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
      perSystem = {
        config,
        self',
        inputs',
        system,
        ...
      }: let
        overlays = [
          (import rust-overlay)
          (
            final: prev: {
              python39 = prev.python39.override {
                packageOverrides = python-final: python-prev: {
                  dnspython = python-prev.dnspython.overrideAttrs (old: {
                    disabledTests =
                      old.disabledTests
                      ++ [
                        "testCanonicalNameCNAME"
                        "testCanonicalNameDangling"
                        "testQueryUDPFallback"
                        "testQueryUDPFallbackWithSocket"
                        "testZoneForName1"
                        "testZoneForName2"
                      ];
                  });
                };
              };
            }
          )
        ];
        pkgs = import nixpkgs {inherit system overlays;};
      in {
        packages = pkgs.callPackage ./tags {inherit pkgs;};

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.nix-prefetch-git
            (pkgs.python3.withPackages (ps: [
              ps.pex
              ps.aiofiles
              ps.mypy
              ps.pytest
              ps.requests
              ps.types-requests
            ]))
          ];
        };
      };
    };
}
