{
  description = "Pants build system Nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
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
        genPython = pkgs.python39.withPackages (ps: [
          ps.pex
          ps.aiofiles
          ps.mypy
          ps.pytest
          ps.requests
          ps.types-requests
        ]);

        genWrapper = pkgs.writeShellApplication {
          name = "gen-releases";
          runtimeInputs = [pkgs.cacert pkgs.nix-prefetch-git genPython];
          text = ''
            export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            export REQUESTS_CA_BUNDLE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            python -m gen "$@"
          '';
        };
      in {
        packages = pkgs.callPackage ./tags {inherit pkgs;};

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.cacert
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
          shellHook = ''
            export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            export REQUESTS_CA_BUNDLE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
          '';
        };
      };
    };
}
