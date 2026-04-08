{ lib, stdenv, jq, coreutils, gnugrep }:

let
  inherit (lib) concatStringsSep mapAttrsToList flatten;

  generate = fetched:
    let
      build = name: available:
        mapAttrsToList
          (version: data:
            if data ? storePath && data.storePath != null
            then
              let
                directory = "$out/modules/${name}/${version}";
                descriptor = "${directory}/source.json";
                target = "file://${data.storePath}";
              in
              ''
                if [ -f "${descriptor}" ]; then
                  ${jq}/bin/jq --arg url "${target}" '.url = $url' "${descriptor}" > "${descriptor}.tmp"
                  ${coreutils}/bin/mv "${descriptor}.tmp" "${descriptor}"
                  ${coreutils}/bin/echo "SUCCESS" >> "$STATS_FILE"
                fi
              ''
            else
              ""
          )
          available;

      commands = flatten (mapAttrsToList build fetched);
    in
    concatStringsSep "\n" commands;

  rewrite = { registry, fetched }:
    stdenv.mkDerivation {
      name = "hermetic-bazel-registry";
      src = registry;

      nativeBuildInputs = [ jq coreutils gnugrep ];

      script = generate fetched;
      passAsFile = [ "script" ];

      buildPhase = ''
        ${coreutils}/bin/cp -r $src $out
        ${coreutils}/bin/chmod -R +w $out

        export STATS_FILE=$(${coreutils}/bin/mktemp)

        ${stdenv.shell} "$scriptPath"

        success=$(${coreutils}/bin/cat "$STATS_FILE" | ${gnugrep}/bin/grep -c "SUCCESS" || ${coreutils}/bin/echo "0")

        ${coreutils}/bin/echo ""
        ${coreutils}/bin/echo "Registry rewrite summary:"
        ${coreutils}/bin/echo "  Modules rewritten: $success"

        ${coreutils}/bin/rm "$STATS_FILE"
      '';
    };

in
{
  inherit rewrite;
}
