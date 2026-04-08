{ lib, stdenv, coreutils, jq, parse }:

let
  inherit (builtins) pathExists;
  inherit (lib) concatStringsSep flatten mapAttrsToList foldl;

  select = registry: requested:
    let
      directory = "${registry}/modules";

      extract = { name, version }:
        let
          location = "${directory}/${name}";
          target = "${location}/${version}";
          descriptor = "${target}/source.json";
          data = parse.source descriptor;
        in
        if !pathExists target then
          throw "Module ${name}@${version} not found at ${target}"
        else if data == null then
          throw "Module ${name}@${version} missing source.json at ${descriptor}"
        else {
          inherit name version;
          sourceData = data;
          path = target;
        };

      selected = map extract requested;

      combine = list:
        foldl
          (acc: item:
            let
              existing = acc.${item.name} or { };
              updated = existing // {
                ${item.version} = {
                  inherit (item) sourceData path;
                };
              };
            in
            acc // { ${item.name} = updated; }
          )
          { }
          list;
    in
    combine selected;

  minimal = { registry, modules }:
    let
      selected = select registry modules;

      build = name: available:
        mapAttrsToList
          (version: _data:
            ''
              ${coreutils}/bin/mkdir -p "$out/modules/${name}"
              if [ -d "${registry}/modules/${name}/${version}" ]; then
                ${coreutils}/bin/cp -r "${registry}/modules/${name}/${version}" "$out/modules/${name}/"
              else
                echo "ERROR: Version ${name}@${version} not found"
                exit 1
              fi

              if [ -f "${registry}/modules/${name}/metadata.json" ] && [ ! -f "$out/modules/${name}/metadata.json" ]; then
                ${coreutils}/bin/cp "${registry}/modules/${name}/metadata.json" "$out/modules/${name}/"
              fi
            ''
          )
          available;

      commands = concatStringsSep "\n" (flatten (mapAttrsToList build selected));
    in
    stdenv.mkDerivation {
      name = "selected-bazel-registry";
      nativeBuildInputs = [ coreutils jq ];
      dontUnpack = true;

      buildPhase = ''
        ${coreutils}/bin/mkdir -p $out/modules

        if [ -f ${registry}/bazel_registry.json ]; then
          ${coreutils}/bin/cp ${registry}/bazel_registry.json $out/
        else
          ${jq}/bin/jq -n '{"module_base_path": ""}' > $out/bazel_registry.json
        fi

        ${commands}
      '';
    };

in
{
  inherit minimal;
}
