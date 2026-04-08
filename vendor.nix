{ stdenv
, fetchFromGitHub
, coreutils
, jq
, gnutar
, gzip
, runCommand
}:

let
  impl = import ./vendor/builtins.nix {
    inherit stdenv fetchFromGitHub coreutils jq gnutar gzip runCommand;
  };

  builtins = impl.registry { version = "7.6.0"; };

in
{
  inherit builtins;
}
