{ stdenv
, fetchFromGitHub
, coreutils
, jq
, gnutar
, gzip
, runCommand
}:

let
  version = "7.6.0";

  source = fetchFromGitHub {
    owner = "bazelbuild";
    repo = "bazel";
    rev = version;
    hash = "sha256-0bGuzY6nGM/iVMgfWFq9GlUo8DF+S9Obf6/k0CS7Mc8=";
  };

  tarball = stdenv.mkDerivation {
    name = "bazel_tools-${version}.tar.gz";
    nativeBuildInputs = [ coreutils gnutar gzip ];
    dontUnpack = true;

    buildCommand = ''
      ${coreutils}/bin/mkdir -p $out
      cd ${source}
      ${gnutar}/bin/tar czf $out/bazel_tools-${version}.tar.gz tools/
    '';
  };

  registry = { version }:
    stdenv.mkDerivation {
      name = "bazel-builtins-registry-${version}";
      nativeBuildInputs = [ coreutils jq ];
      dontUnpack = true;

      buildCommand = ''
        ${coreutils}/bin/mkdir -p $out/modules/bazel_tools/${version}

        ${jq}/bin/jq -n '{
          "module_base_path": ""
        }' > $out/bazel_registry.json

        ${coreutils}/bin/cat > $out/modules/bazel_tools/${version}/MODULE.bazel <<EOF
        module(
            name = "bazel_tools",
            version = "${version}",
        )
        EOF

        ${jq}/bin/jq -n --arg url "file://${tarball}/bazel_tools-${version}.tar.gz" '{
          url: $url,
          integrity: "",
          strip_prefix: "tools"
        }' > $out/modules/bazel_tools/${version}/source.json

        ${jq}/bin/jq -n '{
          homepage: "https://github.com/bazelbuild/bazel",
          maintainers: [],
          versions: ["${version}"],
          yanked_versions: {}
        }' > $out/modules/bazel_tools/metadata.json
      '';
    };

  external = { source }:
    runCommand "bazel-builtins-external"
      {
        nativeBuildInputs = [ coreutils ];
      } ''
      ${coreutils}/bin/mkdir -p $out/external

      if [ -d "${source}" ]; then
        ${coreutils}/bin/cp -r "${source}"/* $out/external/
      else
        echo "ERROR: Builtins source directory not found"
        exit 1
      fi

      ${coreutils}/bin/cat > $out/VENDOR.bazel <<'EOF'
      pin('@@bazel_tools')
      pin('@@local_config_platform')
      pin('@@rules_java_builtin')
      pin('@@internal_platforms_do_not_use')
      EOF

      echo "Created builtin external directory"
      echo "This is static for this Bazel version and contains only builtin repos"
    '';

in
{
  inherit registry external;
}
