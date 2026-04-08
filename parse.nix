{ lib }:

let
  inherit (builtins) readDir readFile fromJSON pathExists attrNames;
  inherit (lib) nameValuePair filterAttrs;

  source = path:
    if pathExists path
    then fromJSON (readFile path)
    else null;

  modules = registry:
    let
      directory = "${registry}/modules";
    in
    if pathExists directory
    then attrNames (readDir directory)
    else [ ];

  metadata = path:
    let
      location = "${path}/metadata.json";
    in
    if pathExists location
    then fromJSON (readFile location)
    else { yanked_versions = { }; };

  yanked = data: version:
    let
      excluded = data.yanked_versions or { };
    in
    excluded ? ${version};

  versions = path:
    let
      data = metadata path;
      entries = readDir path;

      valid = name: type:
        type == "directory" && !(yanked data name);
    in
    attrNames (filterAttrs valid entries);

  scan = registry:
    let
      names = modules registry;

      process = name:
        let
          location = "${registry}/modules/${name}";
          available = versions location;

          build = version:
            let
              descriptor = "${location}/${version}/source.json";
              data = source descriptor;
            in
            if data != null
            then
              nameValuePair version
                {
                  sourceData = data;
                  path = "${location}/${version}";
                }
            else null;

          present = lib.filter (v: v != null) (map build available);
          attrs = lib.listToAttrs present;
        in
        if attrs != { }
        then nameValuePair name attrs
        else null;

      present = lib.filter (m: m != null) (map process names);
    in
    lib.listToAttrs present;

in
{
  inherit source modules versions scan;
}
