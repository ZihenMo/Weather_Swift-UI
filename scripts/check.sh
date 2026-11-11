#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
xcrun swift-format lint --strict --recursive WeatherJournal WeatherJournalTests
python3 scripts/validate_project.py
python3 scripts/check_view_style.py
python3 - <<'PY'
from pathlib import Path
import subprocess
for directory in ['WeatherJournal', 'WeatherJournalTests']:
    sources = sorted(str(path) for path in Path(directory).rglob('*.swift'))
    subprocess.run(['xcrun', 'swiftc', '-frontend', '-parse', *sources], check=True)
for path in [Path('WeatherJournal/Resources/Info.plist'), Path('WeatherJournal.xcodeproj/project.pbxproj'), *Path('WeatherJournal/Resources').rglob('*.strings')]:
    subprocess.run(['plutil', '-lint', str(path)], check=True)
for path in Path('scripts').glob('*.sh'):
    subprocess.run(['bash', '-n', str(path)], check=True)
for path in [Path('Gemfile'), Path('fastlane/Pluginfile'), Path('fastlane/Fastfile'), *Path('fastlane').glob('*.rb')]:
    subprocess.run(['ruby', '-c', str(path)], check=True)
PY
git diff --check
printf 'Static checks passed. No application build or tests were run.\n'
