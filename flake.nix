{
  description = "Nixel: Hermetic Bazel registry generation for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self
    , nixpkgs
    ,
    }:
    let
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      each =
        f:
        nixpkgs.lib.genAttrs platforms (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          f { inherit system pkgs; }
        );

    in
    {
      # Public library API
      lib = each (
        { pkgs, ... }:
        pkgs.callPackage ./default.nix { }
      );

      # Integration tests
      checks = each (
        { pkgs, system, ... }:
        let
          tests = pkgs.callPackage ./test.nix { };
        in
        {
          registry-created = tests.testRegistryCreated;
          modules-structure = tests.testModulesStructure;
          source-rewritten = tests.testSourceRewritten;
          vendor-registry = tests.testVendorRegistry;
          bazel-with-vendor = tests.testBazelWithVendor;
          builtins-reusable = tests.testBuiltinsReusable;
        }
      );
    };
}
