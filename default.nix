{ lib
, stdenv
, jq
, coreutils
, gnugrep
, fetchurl
, fetchFromGitHub
, runCommand
, gnutar
, gzip
}:

let
  parse = import ./parse.nix { inherit lib; };
  fetch = import ./fetch.nix { inherit lib fetchurl; };
  registry = import ./registry.nix {
    inherit lib stdenv jq coreutils gnugrep fetchurl;
  };
  vendor = import ./vendor.nix {
    inherit stdenv fetchFromGitHub coreutils jq gnutar gzip runCommand;
  };
  bazelrc = import ./bazelrc.nix {
    inherit lib runCommand coreutils;
  };

in
{
  # Public API: registry operations
  #
  # registry.rewrite { source }: Create hermetic registry from source registry
  #   Returns: { modules = {...}; registry = /nix/store/path; }
  #
  # registry.minimal { registry, modules }: Create registry with only specified modules
  #   modules: [ { name, version } ]
  #   Returns: { modules = {...}; registry = /nix/store/path; }
  #
  # registry.vendor { directory }: Create hermetic registry from vendor directory
  #   directory: path to bazel vendor output
  #   Returns: { modules = {...}; registry = /nix/store/path; }
  inherit registry;

  # Public API: vendor operations
  #
  # vendor.builtins: Bazel 7.6.0 builtins registry
  #   Returns: /nix/store/path to registry
  inherit vendor;

  # Public API: bazelrc generation
  #
  # bazelrc.generate { registries, vendor }: Generate .nix.bazelrc file
  #   registries: [ /nix/store/path ... ] (list of registry paths)
  #   vendor: /nix/store/path to vendor directory
  #   Returns: /nix/store/path to generated .nix.bazelrc
  inherit bazelrc;

  # Internal API: fetch operations
  #
  # fetch.module { sourceData, name, version }: Fetch single module
  # fetch.all scanned: Fetch all modules from scanned registry
  inherit fetch;

  # Internal API: parse operations
  #
  # parse.source path: Parse source.json file
  # parse.modules registry: List module names
  # parse.versions path: List non-yanked versions
  # parse.scan registry: Scan entire registry
  inherit parse;
}
