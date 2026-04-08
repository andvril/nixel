{ lib
, stdenv
, jq
, coreutils
, gnugrep
, runCommand
, fetchFromGitHub
, fetchurl
, gnutar
, gzip
, bazel_7
}:

import ./test/integration.nix {
  inherit lib stdenv jq coreutils gnugrep runCommand fetchFromGitHub fetchurl gnutar gzip bazel_7;
}
