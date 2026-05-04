"""Build a Kong-branded customer success-plan PPTX from a JSON content file.

The bundled template (`templates/kong-success-plan-template.pptx`) is the
official Kong CS three-slide success-plan layout: cover, strategic
objectives, workstreams and milestones. This script clones slide 3 into a
fourth deep-dive slide whenever the content file includes a `deep_dive`
section.

Layout, fonts, footer bar, and Kong brand styling are inherited from the
template. This script only replaces text; it never edits the template's
shapes, geometry, or theme.

Usage:

    python3 scripts/build.py --input <customer.json> --output <out.pptx>

Optional `--template <path>` overrides the bundled template.

Input JSON shape: see `examples/healthequity.json` and the
`Content schema` section of SKILL.md.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import zipfile
from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as ET

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_TEMPLATE = SCRIPT_DIR.parent / "templates" / "kong-success-plan-template.pptx"

A = "http://schemas.openxmlformats.org/drawingml/2006/main"
P = "http://schemas.openxmlformats.org/presentationml/2006/main"

ET.register_namespace("a", A)
ET.register_namespace("p", P)
ET.register_namespace("r", "http://schemas.openxmlformats.org/officeDocument/2006/relationships")

STATUS_LEGEND = (
    "STATUS:  \U0001f535 Complete  |  "
    "\U0001f7e2 On Track  |  "
    "\U0001f7e0 At Risk  |  "
    "\U0001f534 Delayed"
)

# ---------------------------------------------------------------------------
# Shape ID maps for the bundled template. These are the Google Shape IDs
# baked into the bundled `kong-success-plan-template.pptx`, stable across
# rebuilds. Override only if you supply a different `--template` whose
# shapes carry different IDs.
# ---------------------------------------------------------------------------

COVER_SHAPES = {
    "title_block": 164,    # 3 paragraphs: "<Customer> Kong" / "Success Plan" / "<Date>"
    "csm_line": 165,
    "tagline": 166,
}

OBJECTIVES_SHAPES = {
    "title": 187,
    "subtitle": 188,
    "takeaway_label": 177,
    "takeaway_body": 178,
    "items": [
        {"number": 191, "heading": 192, "bullets": 193},
        {"number": 197, "heading": 198, "bullets": 199},
        {"number": 207, "heading": 208, "bullets": 209},
    ],
    "footer_section": 182,
    "footer_copyright": 183,
    "footer_confidential": 184,
    "footer_pageno": 185,
}

WORKSTREAMS_SHAPES = {
    "title": 219,
    "subtitle": 220,
    "items": [
        {"number": 223, "title": 225, "date": 226, "status": 228, "bullets": 229},
        {"number": 234, "title": 236, "date": 237, "status": 239, "bullets": 240},
        {"number": 243, "title": 246, "date": 247, "status": 249, "bullets": 250},
        {"number": 253, "title": 255, "date": 256, "status": 258, "bullets": 259},
    ],
    "footer_kpis": 262,
    "footer_legend": 263,
    "footer_section": 267,
    "footer_copyright": 268,
    "footer_confidential": 269,
    "footer_pageno": 270,
}

# Bullet shapes whose body anchor must be set to top so that longer content
# does not bleed upward into the badge/status pill. These are the four
# workstream/initiative bullet boxes on slide 3 (and the slide 4 clone).
TOP_ANCHOR_BULLET_GIDS = {229, 240, 250, 259}

# After top-anchoring, also extend the bullet box height so that 3-bullet
# content with one or two wrapped lines fits without clipping. The empty
# region below the original cy=1,901,700 box runs to ~y=7,095,744, where
# the success-indicators footer begins.
BULLET_BOX_CY = 2_500_000


# ---------------------------------------------------------------------------
# XML helpers
# ---------------------------------------------------------------------------


def shape_gid(name):
    if not name:
        return None
    m = re.match(r"Google Shape;(\d+);", name)
    return int(m.group(1)) if m else None


def find_shapes(root):
    for sp in root.iter(f"{{{P}}}sp"):
        cnvpr = sp.find(f".//{{{P}}}cNvPr")
        if cnvpr is None:
            continue
        gid = shape_gid(cnvpr.get("name", ""))
        if gid is not None:
            yield sp, gid


def text_runs(paragraph):
    return list(paragraph.findall(f"{{{A}}}r"))


def paragraph_text(paragraph):
    return "".join((t.text or "") for t in paragraph.iter(f"{{{A}}}t"))


def set_run_text(run, text):
    t = run.find(f"{{{A}}}t")
    if t is None:
        t = ET.SubElement(run, f"{{{A}}}t")
    t.text = text


def force_top_anchor(sp):
    bp = sp.find(f".//{{{A}}}bodyPr")
    if bp is not None:
        bp.set("anchor", "t")
    txbody = sp.find(f".//{{{P}}}txBody")
    if txbody is None:
        return
    for p in list(txbody.findall(f"{{{A}}}p")):
        if not paragraph_text(p).strip():
            txbody.remove(p)


def extend_bullet_box(sp):
    ext = sp.find(f".//{{{A}}}xfrm/{{{A}}}ext")
    if ext is not None:
        ext.set("cy", str(BULLET_BOX_CY))


def replace_string_in_shape(sp, value):
    target_p = None
    for p in sp.iter(f"{{{A}}}p"):
        if any((t.text or "").strip() for t in p.iter(f"{{{A}}}t")):
            target_p = p
            break
    if target_p is None:
        first_p = sp.find(f".//{{{A}}}p")
        if first_p is not None:
            runs = text_runs(first_p)
            if runs:
                set_run_text(runs[0], value)
        return
    runs = text_runs(target_p)
    if not runs:
        r = ET.SubElement(target_p, f"{{{A}}}r")
        set_run_text(r, value)
        return
    set_run_text(runs[0], value)
    for extra_r in runs[1:]:
        set_run_text(extra_r, "")


def replace_list_in_shape(sp, items):
    txbody = sp.find(f".//{{{P}}}txBody")
    if txbody is None:
        return
    paragraphs = txbody.findall(f"{{{A}}}p")
    if not paragraphs:
        return
    content_paragraphs = [p for p in paragraphs if paragraph_text(p).strip()]
    if not content_paragraphs:
        content_paragraphs = [paragraphs[0]]
    template_p = content_paragraphs[-1]
    target_paragraphs = list(content_paragraphs)
    while len(target_paragraphs) < len(items):
        clone = deepcopy(template_p)
        last = target_paragraphs[-1]
        last_idx = list(txbody).index(last)
        txbody.insert(last_idx + 1, clone)
        target_paragraphs.append(clone)
    overflow = target_paragraphs[len(items):]
    target_paragraphs = target_paragraphs[: len(items)]
    for p, item in zip(target_paragraphs, items):
        runs = text_runs(p)
        if not runs:
            r = ET.SubElement(p, f"{{{A}}}r")
            set_run_text(r, item)
            continue
        set_run_text(runs[0], item)
        for extra_r in runs[1:]:
            set_run_text(extra_r, "")
    for p in overflow:
        for r in text_runs(p):
            set_run_text(r, "")


def apply_replacements(slide_xml, replacements):
    root = ET.fromstring(slide_xml)
    seen = set()
    for sp, gid in find_shapes(root):
        if gid in TOP_ANCHOR_BULLET_GIDS:
            force_top_anchor(sp)
            extend_bullet_box(sp)
        if gid not in replacements:
            continue
        seen.add(gid)
        value = replacements[gid]
        if isinstance(value, str):
            replace_string_in_shape(sp, value)
        elif isinstance(value, list):
            replace_list_in_shape(sp, value)
    body = ET.tostring(root, encoding="UTF-8")
    if not body.startswith(b"<?xml"):
        body = b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + body
    missing = set(replacements) - seen
    return body, missing


# ---------------------------------------------------------------------------
# Content -> shape replacements
# ---------------------------------------------------------------------------


def cover_replacements(customer):
    name = customer.get("name", "Customer")
    title_lines = [f"{name} Kong", "Success Plan", customer.get("date", "")]
    return {
        COVER_SHAPES["title_block"]: title_lines,
        COVER_SHAPES["csm_line"]: customer.get("csm", ""),
        COVER_SHAPES["tagline"]: customer.get("tagline", ""),
    }


def objectives_replacements(objectives, customer_name):
    repl = {
        OBJECTIVES_SHAPES["title"]: objectives.get("title", "Strategic Objectives Driving the Program"),
        OBJECTIVES_SHAPES["subtitle"]: objectives.get(
            "subtitle", f"{customer_name}'s priority outcomes"
        ),
        OBJECTIVES_SHAPES["takeaway_label"]: "BOTTOM-LINE TAKEAWAY",
        OBJECTIVES_SHAPES["takeaway_body"]: objectives.get("takeaway", ""),
        OBJECTIVES_SHAPES["footer_section"]: objectives.get("footer_section", "AI CONNECTIVITY"),
        OBJECTIVES_SHAPES["footer_copyright"]: "©  Kong Inc.",
        OBJECTIVES_SHAPES["footer_confidential"]: "CONFIDENTIAL  |  NOT TO BE SHARED EXTERNALLY",
        OBJECTIVES_SHAPES["footer_pageno"]: "3",
    }
    items = objectives.get("items", [])
    if len(items) > 3:
        print("WARN: only the first 3 objective items are used; extras ignored.", file=sys.stderr)
    for i, slot in enumerate(OBJECTIVES_SHAPES["items"]):
        if i >= len(items):
            continue
        item = items[i]
        repl[slot["number"]] = str(i + 1)
        repl[slot["heading"]] = item.get("heading", "")
        bullets = item.get("bullets", [])
        if isinstance(bullets, str):
            repl[slot["bullets"]] = bullets
        elif isinstance(bullets, list):
            repl[slot["bullets"]] = bullets
    return repl


def workstreams_replacements(workstreams, page_no, default_title, default_subtitle):
    repl = {
        WORKSTREAMS_SHAPES["title"]: workstreams.get("title", default_title),
        WORKSTREAMS_SHAPES["subtitle"]: workstreams.get("subtitle", default_subtitle),
        WORKSTREAMS_SHAPES["footer_kpis"]: workstreams.get("footer", ""),
        WORKSTREAMS_SHAPES["footer_legend"]: STATUS_LEGEND,
        WORKSTREAMS_SHAPES["footer_section"]: workstreams.get("footer_section", "AI CONNECTIVITY"),
        WORKSTREAMS_SHAPES["footer_copyright"]: "©  Kong Inc.",
        WORKSTREAMS_SHAPES["footer_confidential"]: "CONFIDENTIAL  |  NOT TO BE SHARED EXTERNALLY",
        WORKSTREAMS_SHAPES["footer_pageno"]: str(page_no),
    }
    items = workstreams.get("items", [])
    if len(items) > 4:
        print("WARN: only the first 4 workstream items are used; extras ignored.", file=sys.stderr)
    for i, slot in enumerate(WORKSTREAMS_SHAPES["items"]):
        if i >= len(items):
            continue
        item = items[i]
        repl[slot["number"]] = str(i + 1)
        repl[slot["title"]] = item.get("title", "")
        repl[slot["date"]] = item.get("date", "")
        repl[slot["status"]] = item.get("status", "In Progress")
        bullets = item.get("bullets", [])
        if isinstance(bullets, str):
            repl[slot["bullets"]] = bullets
        elif isinstance(bullets, list):
            repl[slot["bullets"]] = bullets
    return repl


# ---------------------------------------------------------------------------
# PPTX assembly
# ---------------------------------------------------------------------------


def add_deep_dive_slide(parts, deep_dive_repl, content_types):
    """Clone slide 3 into slide 4 with the deep-dive replacements applied."""
    slide3_xml = parts["ppt/slides/slide3.xml"]
    slide4_xml, missing = apply_replacements(slide3_xml, deep_dive_repl)
    parts["ppt/slides/slide4.xml"] = slide4_xml

    # rels: same as slide 3 but pointing at notesSlide4
    slide3_rels = parts["ppt/slides/_rels/slide3.xml.rels"].decode("utf-8")
    parts["ppt/slides/_rels/slide4.xml.rels"] = (
        slide3_rels.replace("notesSlides/notesSlide3.xml", "notesSlides/notesSlide4.xml").encode("utf-8")
    )

    parts["ppt/notesSlides/notesSlide4.xml"] = parts["ppt/notesSlides/notesSlide3.xml"]
    parts["ppt/notesSlides/_rels/notesSlide4.xml.rels"] = parts["ppt/notesSlides/_rels/notesSlide3.xml.rels"]

    # [Content_Types].xml — add slide4 + notesSlide4 overrides
    if "/ppt/slides/slide4.xml" not in content_types:
        new_overrides = (
            '<Override ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml" '
            'PartName="/ppt/slides/slide4.xml"/>'
            '<Override ContentType="application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml" '
            'PartName="/ppt/notesSlides/notesSlide4.xml"/>'
        )
        content_types = content_types.replace("</Types>", new_overrides + "</Types>")
    parts["[Content_Types].xml"] = content_types.encode("utf-8")

    # presentation.xml — add a 4th sldId
    pres_xml = parts["ppt/presentation.xml"].decode("utf-8")
    pres_rels_xml = parts["ppt/_rels/presentation.xml.rels"].decode("utf-8")

    existing_rids = [int(m) for m in re.findall(r'Id="rId(\d+)"', pres_rels_xml)]
    new_rid = max(existing_rids) + 1 if existing_rids else 1000
    new_rid_str = f"rId{new_rid}"

    existing_sld = [int(m) for m in re.findall(r'<p:sldId id="(\d+)"', pres_xml)]
    new_sld_id = max(existing_sld) + 1 if existing_sld else 256

    sld_id_list_close = "</p:sldIdLst>"
    new_sld_entry = f'<p:sldId id="{new_sld_id}" r:id="{new_rid_str}"/>'
    pres_xml = pres_xml.replace(sld_id_list_close, new_sld_entry + sld_id_list_close)
    parts["ppt/presentation.xml"] = pres_xml.encode("utf-8")

    new_rel = (
        f'<Relationship Id="{new_rid_str}" '
        f'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" '
        f'Target="slides/slide4.xml"/>'
    )
    pres_rels_xml = pres_rels_xml.replace("</Relationships>", new_rel + "</Relationships>")
    parts["ppt/_rels/presentation.xml.rels"] = pres_rels_xml.encode("utf-8")

    return missing


def build(content, template_path, output_path):
    customer = content.get("customer", {})
    objectives = content.get("objectives", {})
    workstreams = content.get("workstreams", {})
    deep_dive = content.get("deep_dive")

    # Read template into memory
    with zipfile.ZipFile(template_path, "r") as zin:
        parts = {name: zin.read(name) for name in zin.namelist()}

    all_missing = set()

    # Slide 1: cover
    body, missing = apply_replacements(parts["ppt/slides/slide1.xml"], cover_replacements(customer))
    parts["ppt/slides/slide1.xml"] = body
    all_missing |= missing

    # Slide 2: strategic objectives
    body, missing = apply_replacements(
        parts["ppt/slides/slide2.xml"],
        objectives_replacements(objectives, customer.get("name", "Customer")),
    )
    parts["ppt/slides/slide2.xml"] = body
    all_missing |= missing

    # Slide 3: workstreams + milestones
    body, missing = apply_replacements(
        parts["ppt/slides/slide3.xml"],
        workstreams_replacements(
            workstreams, page_no=4,
            default_title="Workstreams and Milestones",
            default_subtitle="Where we are and where we are driving next",
        ),
    )
    parts["ppt/slides/slide3.xml"] = body
    all_missing |= missing

    # Slide 4: optional deep dive
    slide_count = 3
    if deep_dive:
        deep_dive_repl = workstreams_replacements(
            deep_dive, page_no=5,
            default_title="Initiative Deep Dive",
            default_subtitle="Bottlenecks we know about and the plays we are running",
        )
        ct = parts["[Content_Types].xml"].decode("utf-8")
        missing = add_deep_dive_slide(parts, deep_dive_repl, ct)
        all_missing |= missing
        slide_count = 4

    # Write the output, preserving member order from the source archive.
    output_path.unlink(missing_ok=True)
    written = set()
    with zipfile.ZipFile(template_path, "r") as zin, zipfile.ZipFile(
        output_path, "w", zipfile.ZIP_DEFLATED
    ) as zout:
        for info in zin.infolist():
            zout.writestr(info, parts[info.filename])
            written.add(info.filename)
        for name, data in parts.items():
            if name in written:
                continue
            zout.writestr(name, data)

    if all_missing:
        print(f"NOTE: replacement targeted shapes not found on every slide: {sorted(all_missing)}", file=sys.stderr)

    print(f"wrote {output_path} ({output_path.stat().st_size} bytes, {slide_count} slides)")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description="Build a Kong success-plan PPTX from a JSON content file.")
    parser.add_argument("--input", required=True, help="Path to JSON content file")
    parser.add_argument("--output", required=True, help="Path for the rendered .pptx")
    parser.add_argument(
        "--template",
        default=str(DEFAULT_TEMPLATE),
        help="Override the bundled Kong success-plan template",
    )
    args = parser.parse_args()

    template = Path(args.template).expanduser().resolve()
    if not template.is_file():
        sys.exit(f"template not found: {template}")
    output = Path(args.output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    content = json.loads(Path(args.input).read_text())
    build(content, template, output)


if __name__ == "__main__":
    main()
