{pkgs}: let
  # Function to generate a package for a specific release
  mkRelease = name: pkgs.callPackage (./. + "/${name}") {};

  # Get all subdirectories in the current directory
  releases = builtins.attrNames (builtins.readDir ./.);

  # Filter out non-release directories
  validReleases = builtins.filter (name: builtins.match "release_.*" name != null) releases;

  # Generate an attribute set of all releases
  releaseSet = builtins.listToAttrs (map (name: {
      inherit name;
      value = mkRelease name;
    })
    validReleases);
in
  releaseSet
