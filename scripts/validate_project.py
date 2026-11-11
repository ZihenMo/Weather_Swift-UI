#!/usr/bin/env python3
"""Read-only validation of source membership, localizations, resources and configuration."""
from pathlib import Path
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / 'WeatherJournal.xcodeproj/project.pbxproj'
errors = []

def plist(path):
    return json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))

project = plist(PROJECT)
objects = project['objects']
resolved = {}

def walk(oid, parent=Path()):
    obj = objects[oid]
    path = parent / obj.get('path', '')
    if obj['isa'] == 'PBXGroup':
        for child in obj.get('children', []):
            walk(child, path)
    elif obj['isa'] == 'PBXFileReference':
        resolved[oid] = path

walk(objects[project['rootObject']]['mainGroup'])
for target in (obj for obj in objects.values() if obj['isa'] == 'PBXNativeTarget'):
    directory = target['name']
    expected = {p.relative_to(ROOT) for p in (ROOT / directory).rglob('*.swift')}
    membership = []
    for phase_id in target['buildPhases']:
        phase = objects[phase_id]
        if phase['isa'] == 'PBXSourcesBuildPhase':
            membership.extend(resolved[objects[entry]['fileRef']] for entry in phase['files'])
    if set(membership) != expected or len(membership) != len(set(membership)):
        errors.append(f'{directory}: missing {expected - set(membership)}, unexpected/duplicate {set(membership) - expected}')
    configurations = objects[target['buildConfigurationList']]['buildConfigurations']
    for config_id in configurations:
        config = objects[config_id]
        ref = config.get('baseConfigurationReference')
        if not ref or not (ROOT / resolved[ref]).is_file():
            errors.append(f'{directory} {config["name"]}: missing base xcconfig')

scheme = ET.parse(ROOT / 'WeatherJournal.xcodeproj/xcshareddata/xcschemes/WeatherJournal.xcscheme')
for ref in scheme.findall('.//BuildableReference'):
    if ref.get('BlueprintIdentifier') not in objects:
        errors.append('Scheme refers to an unknown target')

test_action = scheme.find('.//TestAction')
if test_action.get('shouldUseLaunchSchemeArgsEnv') != 'NO' or not any(
    item.get('key') == 'WJ_DISABLE_LIVE_SERVICES' and item.get('value') == '1' and item.get('isEnabled') == 'YES'
    for item in test_action.findall('.//EnvironmentVariable')
):
    errors.append('Debug unit-test host must disable live services explicitly')

resources = ROOT / 'WeatherJournal/Resources'
languages = sorted(resources.glob('*.lproj'))
localizations = {p.name: plist(p / 'Localizable.strings') for p in languages}
base = localizations['en.lproj']
for language, values in localizations.items():
    if set(values) != set(base):
        errors.append(f'{language}: localization keys differ')
    for key in set(base) & set(values):
        if re.findall(r'%(?:\d+\$)?[@df]', base[key]) != re.findall(r'%(?:\d+\$)?[@df]', values[key]):
            errors.append(f'{language}: format placeholders differ for {key}')
for path in (ROOT / 'WeatherJournal').rglob('*.swift'):
    source = path.read_text()
    for key in re.findall(r'LocalizedText\(key: "([^"\n]+)"\)', source):
        if key not in base:
            errors.append(f'{path.relative_to(ROOT)}: missing localization {key}')
    if '/Configuration/' not in str(path) and 'https://' in source:
        errors.append(f'{path.relative_to(ROOT)}: hardcoded service URL')
    if '/UI/' in str(path) and path.name != 'JournalStyle.swift':
        for pattern in [r'Color\(red:', r'\.font\(\.system', r'\.padding\(\d', r'cornerRadius:\s*\d']:
            if re.search(pattern, source):
                errors.append(f'{path.relative_to(ROOT)}: inline style constant ({pattern})')
for path in resources.rglob('Contents.json'):
    document = json.loads(path.read_text())
    for item in document.get('images', []):
        if 'filename' in item and not (path.parent / item['filename']).is_file():
            errors.append(f'{path.relative_to(ROOT)}: missing image {item["filename"]}')
for directory in ['WeatherJournal', 'WeatherJournalTests', 'Configuration', 'scripts', 'fastlane']:
    for path in (ROOT / directory).rglob('*'):
        if path.is_file() and path.suffix in {'.swift', '.py', '.sh', '.rb', '.xcconfig', '.strings'}:
            if any(line.rstrip() != line for line in path.read_text().splitlines()):
                errors.append(f'{path.relative_to(ROOT)}: trailing whitespace')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print('Source membership, scheme, configuration, localization, assets and whitespace: OK')
