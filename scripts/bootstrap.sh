#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
expected_ruby="$(cat .ruby-version)"
actual_ruby="$(ruby -e 'print RUBY_VERSION')"
if [[ "$actual_ruby" != "$expected_ruby" ]]; then
    printf 'Ruby %s is required. Select it with your Ruby version manager.\n' "$expected_ruby" >&2
    exit 1
fi
expected_xcode="$(cat .xcode-version)"
actual_xcode="$(xcodebuild -version | awk '/^Xcode / { print $2 }')"
if [[ "$actual_xcode" != "$expected_xcode" ]]; then
    printf 'Xcode %s is required. Select it using DEVELOPER_DIR or xcode-select.\n' "$expected_xcode" >&2
    exit 1
fi
bundler_version="$(cat .bundler-version)"
if ! ruby -e 'require "rubygems"; exit(Gem::Specification.find_all_by_name("bundler", ARGV[0]).empty? ? 1 : 0)' "$bundler_version"; then
    gem install bundler --version "$bundler_version" --install-dir "$project_root/.tools/gems" --no-document
fi
# Install only the committed resolution; bootstrap never upgrades dependencies.
BUNDLE_FROZEN=true "$project_root/scripts/bundle.sh" install
printf 'Dependencies ready. No application build or upload was performed.\n'
