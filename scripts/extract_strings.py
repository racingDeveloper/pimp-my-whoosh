#!/usr/bin/env python3
"""Lists the localizable keys used in Sources/ (L("…") and SwiftUI string literals), one per line.

Used to check that every <lang>.lproj/Localizable.strings covers all keys:
    python3 scripts/extract_strings.py --check Resources/it.lproj/Localizable.strings
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LITERAL = r'"((?:[^"\\]|\\.)*)"'
OPENERS = [
    r'\bL\(',
    r'\b(?:Text|Button|Label|Toggle|Section|LabeledContent|Picker)\(',
    r'\.(?:help|navigationTitle|accessibilityLabel)\(',
    r'\bprompt: ',
]


def read_literal(text: str, i: int):
    """Reads the Swift string literal opening at text[i] == '"'; interpolations become %@."""
    out, i = [], i + 1
    while text[i] != '"':
        if text.startswith('\\(', i):
            depth, i, in_string = 1, i + 2, False
            while depth:
                c = text[i]
                if c == '"':
                    in_string = not in_string
                elif not in_string:
                    depth += {'(': 1, ')': -1}.get(c, 0)
                i += 1
            out.append('%@')
        elif text[i] == '\\':
            out.append(text[i:i + 2])
            i += 2
        else:
            out.append(text[i])
            i += 1
    return ''.join(out)


def keys() -> set:
    found = set()
    for path in sorted((ROOT / 'Sources').glob('*.swift')):
        text = path.read_text()
        for opener in OPENERS:
            for match in re.finditer(opener + '"', text):
                found.add(read_literal(text, match.end() - 1))
    return found


def strings_file_keys(path: str) -> list:
    text = pathlib.Path(path).read_text()
    return [m.group(1) for m in re.finditer(r'^' + LITERAL + r'\s*=', text, re.M)]


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--check':
        listed = strings_file_keys(sys.argv[2])
        missing = sorted(keys() - set(listed))
        unused = sorted(set(listed) - keys())
        duplicated = sorted({k for k in listed if listed.count(k) > 1})
        for k in missing:
            print('missing:', k)
        for k in duplicated:
            print('duplicated:', k)
        for k in unused:
            print('unused:', k)
        sys.exit(1 if missing or duplicated else 0)
    for k in sorted(keys()):
        print(k)
