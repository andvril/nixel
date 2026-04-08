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

let
  nixel = import ../default.nix {
    inherit lib stdenv jq coreutils gnugrep fetchurl fetchFromGitHub runCommand gnutar gzip;
  };

  minimal = nixel.registry.rewrite {
    source = ./resource/registry/minimal;
  };

  registries_full = ./resource/vendor/full/_registries;

  vendor_full = nixel.registry.vendor {
    directory = runCommand "vendor-with-registries"
      {
        nativeBuildInputs = [ coreutils ];
      } ''
      ${coreutils}/bin/mkdir -p $out/_registries
      ${coreutils}/bin/cp -r ${registries_full}/* $out/_registries/
    '';
  };

  external_impl = import ../vendor/builtins.nix {
    inherit stdenv fetchFromGitHub coreutils jq gnutar gzip runCommand;
  };

  external = external_impl.external {
    source = ./resource/vendor/full/external;
  };

  registries_partial = ./resource/vendor/partial/_registries;

  vendor_partial = nixel.registry.vendor {
    directory = runCommand "vendor-with-registries-2"
      {
        nativeBuildInputs = [ coreutils ];
      } ''
      ${coreutils}/bin/mkdir -p $out/_registries
      ${coreutils}/bin/cp -r ${registries_partial}/* $out/_registries/
    '';
  };

in
{
  testRegistryCreated = runCommand "test-registry-created"
    {
      nativeBuildInputs = [ coreutils ];
    } ''
    if [ ! -d "${minimal.registry}" ]; then
      echo "ERROR: Registry directory was not created"
      exit 1
    fi

    if [ ! -f "${minimal.registry}/bazel_registry.json" ]; then
      echo "ERROR: bazel_registry.json not found"
      exit 1
    fi

    echo "SUCCESS: Registry created"
    ${coreutils}/bin/touch $out
  '';

  testModulesStructure = runCommand "test-modules-structure"
    {
      nativeBuildInputs = [ coreutils ];
    } ''
    echo "Modules attrset structure:"
    echo "${builtins.toJSON minimal.modules}"

    ${coreutils}/bin/touch $out
  '';

  testSourceRewritten = runCommand "test-source-rewritten"
    {
      nativeBuildInputs = [ coreutils jq ];
    } ''
    sourceJson="${minimal.registry}/modules/example/1.0.0/source.json"

    if [ ! -f "$sourceJson" ]; then
      echo "ERROR: source.json not found at $sourceJson"
      exit 1
    fi

    url=$(${jq}/bin/jq -r '.url' "$sourceJson")
    if [[ ! "$url" =~ ^file:///nix/store/ ]]; then
      echo "ERROR: URL was not rewritten to Nix store path"
      echo "Got: $url"
      exit 1
    fi

    echo "SUCCESS: source.json rewritten with store path"
    echo "URL: $url"
    ${coreutils}/bin/touch $out
  '';

  testVendorRegistry = runCommand "test-vendor-registry"
    {
      nativeBuildInputs = [ coreutils ];
    } ''
    if [ ! -d "${vendor_full.registry}" ]; then
      echo "ERROR: Vendor registry was not created"
      exit 1
    fi

    if [ ! -d "${vendor_full.registry}/modules" ]; then
      echo "ERROR: No modules directory in vendor registry"
      exit 1
    fi

    module_count=$(${coreutils}/bin/ls -1 "${vendor_full.registry}/modules" 2>/dev/null | ${coreutils}/bin/wc -l)
    if [ "$module_count" -eq 0 ]; then
      echo "ERROR: Vendor registry has no modules"
      exit 1
    fi

    echo "SUCCESS: Vendor registry created with $module_count modules"
    ${coreutils}/bin/ls -la "${vendor_full.registry}/modules"
    ${coreutils}/bin/touch $out
  '';

  testBazelWithVendor = runCommand "test-bazel-with-vendor"
    {
      nativeBuildInputs = [ bazel_7 coreutils ];
    } ''
    ${coreutils}/bin/cp -r ${./resource/project/basic} ./test-project
    ${coreutils}/bin/chmod -R +w ./test-project
    cd ./test-project

    export TEST_TMPDIR=$(${coreutils}/bin/mktemp -d)

    ${coreutils}/bin/cp -r ${external} $TEST_TMPDIR/vendor
    ${coreutils}/bin/chmod -R +w $TEST_TMPDIR/vendor

    echo "Testing hermetic pipeline with separated concerns..."
    echo "Builtins vendor dir: $TEST_TMPDIR/vendor"
    echo "Hermetic Nix registry: ${vendor_full.registry}"
    echo ""
    echo "Architecture:"
    echo "  - Builtin repos (@@bazel_tools, etc) → vendor_dir"
    echo "  - Module repos (rules_cc, etc) → hermetic registry"
    echo "  - Module sources → /nix/store (fetched by Nix)"
    echo ""

    if [ -d "$TEST_TMPDIR/vendor/external/bazel_tools" ]; then
      echo "✓ Builtin repos present in vendor"
    else
      echo "ERROR: Builtin repos missing"
      exit 1
    fi

    echo "Building with separated builtins and hermetic registry..."
    if ${bazel_7}/bin/bazel \
      --output_base="$TEST_TMPDIR/output" \
      build \
      --vendor_dir=$TEST_TMPDIR/vendor \
      --registry=file://${vendor_full.registry} \
      //...; then
      echo "SUCCESS: Hermetic Bazel build succeeded!"
      echo "  - Builtins from static vendor_dir"
      echo "  - Modules from hermetic registry"
      echo "  - All sources from /nix/store"
    else
      echo "ERROR: Hermetic Bazel build failed"
      exit 1
    fi

    ${coreutils}/bin/rm -rf "$TEST_TMPDIR"
    ${coreutils}/bin/touch $out
  '';

  testBuiltinsReusable = runCommand "test-builtins-reusable"
    {
      nativeBuildInputs = [ bazel_7 coreutils ];
    } ''
    ${coreutils}/bin/cp -r ${./resource/project/complex} ./test-project-2
    ${coreutils}/bin/chmod -R +w ./test-project-2
    cd ./test-project-2

    export TEST_TMPDIR=$(${coreutils}/bin/mktemp -d)

    ${coreutils}/bin/cp -r ${external} $TEST_TMPDIR/vendor
    ${coreutils}/bin/chmod -R +w $TEST_TMPDIR/vendor

    echo "Testing builtins reusability across projects..."
    echo "Project 2 with DIFFERENT dependencies (rules_python, rules_proto)"
    echo "Using SAME builtins: $TEST_TMPDIR/vendor"
    echo "Using DIFFERENT registry: ${vendor_partial.registry}"
    echo ""

    if [ -d "$TEST_TMPDIR/vendor/external/bazel_tools" ]; then
      echo "✓ Builtins from project 1 reused for project 2"
    else
      echo "ERROR: Builtins missing"
      exit 1
    fi

    echo "Building project 2 with reused builtins..."
    if ${bazel_7}/bin/bazel \
      --output_base="$TEST_TMPDIR/output" \
      build \
      --vendor_dir=$TEST_TMPDIR/vendor \
      --registry=file://${vendor_partial.registry} \
      //...; then
      echo "SUCCESS: Project 2 built with reused builtins!"
      echo "This proves builtins are static per Bazel version"
      echo ""
      echo "Registry comparison:"
      echo "  Project 1: bazel_skylib 1.6.1, rules_cc, googletest"
      echo "  Project 2: bazel_skylib 1.5.0, rules_python, rules_proto"
      echo "  Builtins: IDENTICAL (@@bazel_tools, @@local_config_platform, etc)"
    else
      echo "ERROR: Project 2 build failed"
      exit 1
    fi

    ${coreutils}/bin/rm -rf "$TEST_TMPDIR"
    ${coreutils}/bin/touch $out
  '';

  inherit minimal vendor_full vendor_partial external;
  cleanVendor = vendor_full;
}
