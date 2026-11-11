#!/usr/bin/env python3
"""按格式化后的源码检查 View 长度、嵌套、成员顺序和预览入口。"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
MAX_MEMBER_LINES = 40
MAX_FILE_LINES = 300
MAX_NESTING = 4

# 保留换行与位置，避免字符串、插值和注释中的括号影响结构计数。
LITERALS = re.compile(r'//[^\n]*|/\*[\s\S]*?\*/|"""[\s\S]*?"""|"(?:\\.|[^"\\])*"')
MEMBERS = re.compile(r'\b(var|func)\s+(\w+)\b[^{};]*?(?:\bsome\s+(?:View|Scene))\s*\{')
VIEW_TYPES = re.compile(r'\bstruct\s+(\w+)\b[^{}]*:\s*[^{}]*\bView\b[^{}]*\{')
errors = []
member_count = 0
maximum = 0


def mask(source):
    return LITERALS.sub(lambda match: ''.join('\n' if c == '\n' else ' ' for c in match[0]), source)


def pairs(source):
    stack, result = [], {}
    for index, character in enumerate(source):
        if character == '{':
            stack.append(index)
        elif character == '}' and stack:
            result[stack.pop()] = index
    return result


def location(path, source, position):
    return f'{path.relative_to(ROOT)}:{source.count(chr(10), 0, position) + 1}'


for path in sorted((ROOT / 'WeatherJournal').rglob('*.swift')):
    source = path.read_text()
    code = mask(source)
    braces = pairs(code)
    views = list(VIEW_TYPES.finditer(code))
    if views:
        lines = sum(bool(line.strip()) for line in code.splitlines())
        if lines > MAX_FILE_LINES:
            errors.append(f'{path.relative_to(ROOT)}: View 文件 {lines} 行，限制 {MAX_FILE_LINES}')
        if 'PreviewSupport' not in path.parts and not re.search(r':\s*PreviewProvider\b|#Preview\s*\(', code):
            errors.append(f'{path.relative_to(ROOT)}: 缺少文件内 Preview')
    for match in MEMBERS.finditer(code):
        opening = match.end() - 1
        if opening not in braces:
            continue
        content = code[opening + 1:braces[opening]]
        lines = sum(bool(line.strip()) for line in content.splitlines())
        member_count += 1
        maximum = max(maximum, lines)
        depth = peak = 0
        for character in content:
            if character == '{':
                depth += 1
                peak = max(peak, depth)
            elif character == '}':
                depth -= 1
        where = location(path, source, match.start())
        if lines > MAX_MEMBER_LINES:
            errors.append(f'{where}: {match[2]} 为 {lines} 行，限制 {MAX_MEMBER_LINES}')
        if peak > MAX_NESTING:
            errors.append(f'{where}: {match[2]} 嵌套 {peak} 层，限制 {MAX_NESTING}')
    for view in views:
        opening = view.end() - 1
        if opening not in braces:
            continue
        content = code[opening + 1:braces[opening]]
        offset, depth, order = opening + 1, 0, -1
        for line in content.splitlines(keepends=True):
            if depth == 0:
                declaration = line.strip()
                field = re.search(r'\b(let|var)\s+\w+', declaration)
                if field:
                    if re.match(r'@Environment(?:Object)?\b', declaration):
                        rank = 0
                    elif re.match(r'@(ObservedObject|StateObject)\b', declaration):
                        rank = 1
                    elif re.match(r'@(State|Binding|FocusState|ScaledMetric)\b', declaration):
                        rank = 2
                    elif field[1] == 'var' and '{' in declaration and '=' not in declaration.split('{', 1)[0]:
                        rank = 4
                    else:
                        rank = 3
                    # 同义分组可通过明确的中文注释说明，检查器保留人工复核入口。
                    original_line = source[offset:offset + len(line)]
                    grouped = 'view-style: grouped' in original_line
                    if rank < order and rank < 4 and not grouped:
                        errors.append(f'{location(path, source, offset)}: {view[1]} 属性顺序不符合规范')
                    order = max(order, rank)
            depth += line.count('{') - line.count('}')
            offset += len(line)
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print(f'View 规范：{member_count} 个视图成员，最大 {maximum} 行；长度、嵌套、属性顺序及 Preview 检查通过')
