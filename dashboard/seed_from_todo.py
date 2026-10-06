#!/usr/bin/env python3
"""Convert TODO.md checkboxes into dashboard/features.yaml.

Re-run any time to refresh the structured tracker from TODO.md, so the board
stays in sync without hand-writing hundreds of items.
"""
import os
import re

try:
    import yaml
except ImportError:
    raise SystemExit("Missing dependency: pip install pyyaml")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TODO = os.path.join(ROOT, "docs", "TODO.md")
OUT = os.path.join(ROOT, "dashboard", "features.yaml")

STATUS = {"x": "done", "~": "partial", " ": "pending"}
_section_re = re.compile(r"^#{1,4}\s+(.*)")
_item_re = re.compile(r"^\s*-\s*\[([ x~])\]\s*(.+)")


def _clean(text):
    text = re.sub(r"[*`]", "", text)
    return text.strip()


def main():
    sections = []
    current = None
    with open(TODO, encoding="utf-8") as handle:
        for line in handle:
            sec = _section_re.match(line)
            if sec:
                current = {"name": _clean(sec.group(1)), "items": []}
                sections.append(current)
                continue
            item = _item_re.match(line)
            if item and current is not None:
                current["items"].append({
                    "title": _clean(item.group(2)),
                    "status": STATUS[item.group(1)],
                })
    sections = [s for s in sections if s["items"]]
    doc = {"meta": {"app": "CosmicGuide", "source": "docs/TODO.md"}, "sections": sections}
    with open(OUT, "w", encoding="utf-8") as handle:
        yaml.safe_dump(doc, handle, sort_keys=False, allow_unicode=True, width=100)
    total = sum(len(s["items"]) for s in sections)
    print(f"wrote {OUT}: {len(sections)} sections, {total} items")


if __name__ == "__main__":
    main()
