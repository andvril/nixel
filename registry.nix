{ lib, stdenv, jq, coreutils, gnugrep, fetchurl }:

let
  parse = import ./parse.nix { inherit lib; };
  fetch = import ./fetch.nix { inherit lib fetchurl; };

  impl = {
    rewrite = import ./registry/rewrite.nix {
      inherit lib stdenv jq coreutils gnugrep;
    };
    minimal = import ./registry/minimal.nix {
      inherit lib stdenv coreutils jq parse;
    };
    vendor = import ./registry/vendor.nix {
      inherit lib parse fetch;
    };
  };

  extract = fetched:
    lib.mapAttrs
      (_name: available:
        lib.mapAttrs
          (_version: data: data.storePath)
          available
      )
      fetched;

  rewrite = { source }:
    let
      scanned = parse.scan source;
      fetched = fetch.all scanned;
      registry = impl.rewrite.rewrite {
        registry = source;
        inherit fetched;
      };
    in
    {
      modules = extract fetched;
      inherit registry;
    };

  minimal = { registry, modules }:
    let
      selected = impl.minimal.minimal {
        inherit registry modules;
      };
      scanned = parse.scan selected;
      fetched = fetch.all scanned;
      result = impl.rewrite.rewrite {
        registry = selected;
        inherit fetched;
      };
    in
    {
      modules = extract fetched;
      registry = result;
    };

  vendor = { directory }:
    let
      extracted = impl.vendor.vendor {
        inherit directory;
      };
      scanned = parse.scan extracted.registry;
      fetched = fetch.all scanned;
      registry = impl.rewrite.rewrite {
        inherit (extracted) registry;
        inherit fetched;
      };
    in
    {
      modules = extract fetched;
      inherit registry;
    };

in
{
  inherit rewrite minimal vendor;
}
