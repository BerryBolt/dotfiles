#!/usr/bin/env python3
"""Keep unrelated global instructions and maintain the scoped dotfiles block."""
from pathlib import Path
import sys

original = sys.stdin.read()
policy = Path.home() / 'brain/policies/writing.md'
# Replace only the previous writing-only link content, not custom instructions.
if policy.exists() and original == policy.read_text():
    original = ''
start, end = '<!-- dotfiles instructions -->', '<!-- /dotfiles instructions -->'
block = '''<!-- dotfiles instructions -->
Read ~/brain/policies/writing.md and apply its writing rules to your prose.

For changes in ~/brain or the active dotfiles source returned by chezmoi
source-path, read ~/brain/policies/publication.md before editing or publishing.
Before reporting a durable change complete, publish reviewed whole files and
verify the intended remote destination with a fresh read. New files and deletions
count. Preserve other sessions' work. If blocked, report the specific next action.
Other repositories keep their own workflow. If a referenced policy is missing,
report the missing prerequisite instead of claiming completion.
<!-- /dotfiles instructions -->'''
if original.count(start) != original.count(end) or original.count(start) > 1:
    sys.exit('Global instruction markers are damaged; preserve and resolve them manually')
if start in original:
    before, rest = original.split(start)
    _, after = rest.split(end)
    original = before + block + after
else:
    original += ('\n\n' if original and not original.endswith('\n\n') else '') + block + '\n'
sys.stdout.write(original)
