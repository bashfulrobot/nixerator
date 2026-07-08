#!/usr/bin/env python3
"""
Kong brand-compliance audit: mechanical pass.

Scans a file or directory of text-based source (CSS/HTML/SVG/JS/JSON/etc.) for:
  - hex color codes that aren't in Kong's official 2026 v1.1 palette
  - font-family declarations that name something other than Kong's three
    approved typefaces (or their documented fallback stacks)

This catches the objectively-checkable half of a brand audit. It does NOT
catch logo distortion/recoloring, missing trademark disclaimers, "your brand
more prominent than Kong's", or other judgment calls covered in
references/trademark-usage.md and references/logo-usage.md — walk that
checklist by hand after running this script.

Usage:
    python3 brand-audit.py <file-or-directory> [file-or-directory ...]

Exit code 0 if nothing off-brand was found, 1 if any violation was found.
"""

import json
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
TOKENS_PATH = SCRIPT_DIR.parent / "assets" / "tokens" / "kong-brand.json"

# Skip these outright — binaries, vendor/build output, VCS internals.
SKIP_DIR_NAMES = {".git", "node_modules", "dist", "build", "__pycache__", ".venv"}
BINARY_SUFFIXES = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".eps", ".ai", ".pdf",
    ".ttf", ".otf", ".woff", ".woff2", ".zip", ".pyc",
}

HEX_RE = re.compile(r"#[0-9A-Fa-f]{6}\b|#[0-9A-Fa-f]{3}\b")
FONT_FAMILY_RE = re.compile(r"font-family\s*[:=]\s*[\"']?([^;\"'}\n]+)", re.IGNORECASE)

APPROVED_FALLBACKS = {
    "helvetica neue", "helvetica", "arial", "sans-serif",
    "sfmono-regular", "menlo", "monospace",
}


def load_approved_colors():
    data = json.loads(TOKENS_PATH.read_text())
    hexes = set()
    for entry in data["color"]["brand"].values():
        hexes.add(entry["value"].lower())
    for hexval in data["color"]["neutral"].values():
        hexes.add(hexval.lower())
    return hexes


def load_approved_fonts():
    data = json.loads(TOKENS_PATH.read_text())
    fonts = set()
    for entry in data["typography"]["fontFamily"].values():
        fonts.add(entry["value"].lower())
    return fonts | APPROVED_FALLBACKS


def expand_short_hex(h):
    """#abc -> #aabbcc for comparison purposes."""
    if len(h) == 4:  # '#' + 3 chars
        return "#" + "".join(c * 2 for c in h[1:])
    return h


def iter_target_files(paths):
    for raw in paths:
        p = Path(raw)
        if p.is_file():
            yield p
        elif p.is_dir():
            for f in p.rglob("*"):
                if not f.is_file():
                    continue
                if any(part in SKIP_DIR_NAMES for part in f.parts):
                    continue
                if f.suffix.lower() in BINARY_SUFFIXES:
                    continue
                yield f
        else:
            print(f"warning: {raw} does not exist, skipping", file=sys.stderr)


def audit_file(path, approved_colors, approved_fonts):
    findings = []
    try:
        text = path.read_text(errors="ignore")
    except Exception as e:
        print(f"warning: could not read {path}: {e}", file=sys.stderr)
        return findings

    for lineno, line in enumerate(text.splitlines(), start=1):
        for m in HEX_RE.finditer(line):
            hexval = expand_short_hex(m.group(0).lower())
            if hexval not in approved_colors:
                findings.append((lineno, "off-palette color", m.group(0)))

        for m in FONT_FAMILY_RE.finditer(line):
            # font-family can list a stack; check each comma-separated name.
            names = [n.strip().strip("'\"") for n in m.group(1).split(",")]
            for name in names:
                if not name or name.lower().startswith("var("):
                    continue
                if name.lower() not in approved_fonts:
                    findings.append((lineno, "off-brand font-family", name))

    return findings


def main(argv):
    if not argv:
        print(__doc__)
        return 2

    approved_colors = load_approved_colors()
    approved_fonts = load_approved_fonts()

    total_findings = 0
    for path in iter_target_files(argv):
        findings = audit_file(path, approved_colors, approved_fonts)
        if findings:
            print(f"\n{path}")
            for lineno, kind, value in findings:
                print(f"  line {lineno}: {kind}: {value}")
            total_findings += len(findings)

    print()
    if total_findings:
        print(f"FAIL: {total_findings} off-brand value(s) found.")
        print("Cross-check against references/colors.md and references/typography.md")
        print("before flagging — see references/drift-and-consolidation.md if this is")
        print("an older Kong skill's output, not new work.")
        return 1
    else:
        print("PASS: no off-palette colors or off-brand fonts found.")
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
