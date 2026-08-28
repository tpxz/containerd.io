#!/usr/bin/env python3
"""Verify that the Chinese translation kept every heading anchor of the English original.

Translated headings change the auto-generated id, which silently breaks in-page
links, cross-page links and every external deep link into the docs. The
translation rule is that each translated heading carries the original anchor as
`## 中文标题 {#original-anchor}`; this script checks that the rule held.

For every translated file it compares the set of anchors against the upstream
English source and reports:

  MISSING  an anchor the English page had and the translation does not
  DEAD     a `](#target)` link inside the file pointing at no anchor

Usage: python tools/check-anchors.py [VERSION]   (default 2.3)
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = sys.argv[1] if len(sys.argv) > 1 else "2.3"

FENCE = re.compile(r"^\s*(```|~~~)")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
EXPLICIT_ID = re.compile(r"\{#([^}\s]+)\}\s*$")
LINK = re.compile(r"\]\(\s*(#[^)\s]+)")
# Inline markup keeps its text but loses its punctuation: "From `apt-get`" has
# to slug as "from-apt-get", not "from-".
CODE = re.compile(r"`([^`]*)`")
INLINE_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
# Underscores survive into GitHub slugs (skip_verify -> #skip_verify-field),
# so only * and ~ are stripped as emphasis markers.
EMPHASIS = re.compile(r"[*~]")


def github_slug(text, seen):
    """Reproduce Hugo's default (github) heading id generation."""
    text = CODE.sub(lambda m: m.group(1), text)
    text = INLINE_LINK.sub(lambda m: m.group(1), text)
    text = EMPHASIS.sub("", text)
    slug = text.strip().lower()
    slug = "".join(c for c in slug if c.isalnum() or c in " -_" or ord(c) > 127)
    slug = slug.replace(" ", "-")
    n = seen.get(slug, 0)
    seen[slug] = n + 1
    return slug if n == 0 else f"{slug}-{n}"


def parse(path):
    """Return (anchors, in-page link targets) for a markdown file."""
    anchors, links, seen = [], [], {}
    in_fence = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = HEADING.match(line)
        if m:
            title = m.group(2)
            explicit = EXPLICIT_ID.search(title)
            if explicit:
                anchors.append(explicit.group(1))
                seen[explicit.group(1)] = seen.get(explicit.group(1), 0) + 1
            else:
                anchors.append(github_slug(title, seen))
        links.extend(t[1:] for t in LINK.findall(line))
    return anchors, links


def main():
    translated_root = ROOT / "content" / "docs" / VERSION
    english_root = ROOT / f"containerd-{VERSION}" / "docs"
    if not translated_root.is_dir():
        sys.exit(f"no such directory: {translated_root}")

    problems = 0
    checked = 0
    for path in sorted(translated_root.rglob("*.md")):
        rel = path.relative_to(translated_root)
        if "historical" in rel.parts:
            continue
        source = (ROOT / f"containerd-{VERSION}" / "README.md") if rel.as_posix() == "_index.md" \
            else english_root / rel
        if not source.is_file():
            continue  # auto-generated section _index.md, no upstream original
        checked += 1

        new_anchors, new_links = parse(path)
        old_anchors, old_links = parse(source)

        missing = [a for a in old_anchors if a not in new_anchors]
        # Only links the translation broke; the English original has a few that
        # never resolved either (wrong case, renamed sections upstream).
        already_dead = {t for t in old_links if t not in old_anchors}
        dead = [t for t in new_links if t not in new_anchors and t not in already_dead]
        for a in missing:
            print(f"MISSING  {rel.as_posix()}  #{a}")
            problems += 1
        for t in dict.fromkeys(dead):
            print(f"DEAD     {rel.as_posix()}  ](#{t})")
            problems += 1

    print(f"\nchecked {checked} files, {problems} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
