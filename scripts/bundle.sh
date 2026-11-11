#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
bundler_version="$(cat .bundler-version)"
export BUNDLE_USER_HOME="$project_root/.tools/bundler"
export BUNDLE_PATH="$project_root/vendor/bundle"
export FASTLANE_SKIP_UPDATE_CHECK=1
export FASTLANE_OPT_OUT_USAGE=1
export FASTLANE_HIDE_CHANGELOG=1
local_bundler="$project_root/.tools/gems/gems/bundler-$bundler_version/exe/bundle"
if [[ -f "$local_bundler" ]]; then
    exec ruby "$local_bundler" "$@"
fi
exec bundle "_$bundler_version"_ "$@"
