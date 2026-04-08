_:

let
  vendor = { directory }:
    {
      registry = "${directory}/_registries/bcr.bazel.build";
    };

in
{
  inherit vendor;
}
