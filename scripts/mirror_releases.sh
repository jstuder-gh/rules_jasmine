#!/usr/bin/env bash
# Produce a dictionary for the current esbuild release,
# suitable for appending to esbuild/private/versions.bzl
set -o errexit -o nounset
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

version="${1:-$(curl --silent "https://registry.npmjs.org/jasmine/latest" | jq --raw-output ".version")}"
out="$SCRIPT_DIR/../jasmine/private/v${version}"
mkdir -p "$out"

cd $(mktemp -d)
npx pnpm install "jasmine@$version"  --lockfile-only
touch BUILD
cat >WORKSPACE <<EOF
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "aspect_rules_js",
    sha256 = "f2b36aac9d3368e402c9083c884ad9b26ca6fa21e83b53c12482d6cb2e949451",
    strip_prefix = "rules_js-1.0.0-rc.4",
    url = "https://github.com/aspect-build/rules_js/archive/refs/tags/v1.0.0-rc.4.tar.gz",
)

load("@aspect_rules_js//js:repositories.bzl", "rules_js_dependencies")

rules_js_dependencies()

load("@rules_nodejs//nodejs:repositories.bzl", "nodejs_register_toolchains")

nodejs_register_toolchains(
    name = "nodejs",
    node_version = "16.9.0",
)

load("@aspect_rules_js//npm:npm_import.bzl", "npm_translate_lock")

npm_translate_lock(
    name = "npm_aspect_rules_jasmine",
    pnpm_lock = "//:pnpm-lock.yaml",
    public_hoist_packages = {
        "jasmine-core": [""]
    }
)

load("@npm_aspect_rules_jasmine//:repositories.bzl", "npm_repositories")

npm_repositories()
EOF
bazel info output_base
bazel fetch @npm_aspect_rules_jasmine//:all
cp $(bazel info output_base)/external/npm_aspect_rules_jasmine/{defs,repositories}.bzl "$out"
echo "Mirrored jasmine version $version to $out. Now add it to jasmine/private/versions.bzl"
