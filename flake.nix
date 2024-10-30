{
  description = "Pants build system Nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      imports = [ ./nix/pants.nix ];
      perSystem = { config, pkgs, system, ... }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              (import inputs.rust-overlay)
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
                      django = python-prev.django_4.overrideAttrs (old: {
                        disabled = python-prev.pythonOlder "3.9";
                      });
                    };
                  };
                }
              )

            ];
          };

          pants = {
            version = "2.22.0";
            hash = "sha256-1dmT41gmwgQz4gL2Ga51r1e48zqRSWXzWXORrH5ztag=";
            python = pkgs.python39;
          };

          packages.default = config.pants.package;
          packages.pants-cache-key = config.pants.scripts.pants-cache-key;

          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [ config.pants.package config.pants.scripts.pants-cache-key];
            packages = [
              pkgs.cacert
              pkgs.nix-prefetch-git
              config.pants.package
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
