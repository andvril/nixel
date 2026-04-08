{ lib, fetchurl }:

let
  inherit (lib) hasPrefix last splitString;

  supported = integrity:
    hasPrefix "sha256-" integrity || hasPrefix "sha512-" integrity;

  algorithm = hash:
    if hasPrefix "sha256-" hash then "sha256"
    else if hasPrefix "sha512-" hash then "sha512"
    else throw "Unsupported hash algorithm: ${hash}";

  filename = url:
    let
      without = builtins.head (splitString "?" url);
      segments = splitString "/" without;
    in
    last segments;

  archive = { url, name, hash }:
    fetchurl {
      inherit url;
      name = filename url;
      ${algorithm hash} = hash;
    };

  module = { sourceData, name, version }:
    let
      url = sourceData.url or null;
      integrity = sourceData.integrity or null;
      label = "${name}-${version}";
    in
    if url == null then null
    else if integrity == null then null
    else if !supported integrity then null
    else
      archive {
        inherit url;
        name = label;
        hash = integrity;
      };

  all = scanned:
    lib.mapAttrs
      (name: available:
        lib.mapAttrs
          (version: data:
            let
              complete = data.sourceData != null
                && data.sourceData ? url
                && data.sourceData.url != null
                && data.sourceData ? integrity
                && data.sourceData.integrity != null;

              attempt = builtins.tryEval (module {
                inherit (data) sourceData;
                inherit name version;
              });

              success = attempt.success && attempt.value != null;

              unsupported = !supported data.sourceData.integrity;
            in
            if !complete then
              throw "${name}@${version} has incomplete source metadata"
            else if !success && unsupported then
              throw "${name}@${version} uses unsupported hash: ${data.sourceData.integrity}"
            else if !success then
              throw "${name}@${version} failed to fetch"
            else
              data // { storePath = attempt.value; }
          )
          available
      )
      scanned;

in
{
  inherit module all;
}
