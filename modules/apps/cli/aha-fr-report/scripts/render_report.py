#!/usr/bin/env python3
"""Render a customer's Aha! feature-request list into a Kong-branded,
self-contained HTML report (White theme, print-friendly). Meant to be piped
into wkhtmltopdf immediately after; every asset is referenced by local
file:// path (fonts, logo), so the HTML only needs to survive long enough to
be rendered on this machine.

With --format csv it instead emits the same data as a customer-facing CSV
(export-customer-csv.sh's data source) -- identical row ordering to the PDF,
so the two customer-facing artifacts always agree. The CSV keeps the Source
Link and Internal Discussion Link columns as bare URLs but, like the PDF,
omits the internal-only Aha Link / Proxy Vote Link columns the Sheet carries.

Usage:
    render_report.py [--format html|csv] CUSTOMER_NAME < ideas.json > report.html
"""
import csv
import json
import os
import sys
import datetime

# Assets live in ../assets relative to this script (vendored alongside it in
# the Nix package -- see default.nix's `src` derivation), not a hardcoded
# personal path, so this works identically on srv and any workstation.
ASSETS_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
)
# wkhtmltopdf's rendering engine has weak SVG support (the Kong press-kit SVG
# silently failed to render), so use a rasterized PNG instead. Regenerate
# with: inkscape Kong-Logotype-transparent.svg --export-type=png
# --export-height=200 --export-filename=kong-logotype-light.png
LOGO = os.path.join(ASSETS_DIR, "kong-logotype-light.png")
FONT_DIR = os.path.join(ASSETS_DIR, "fonts")

CLOSED_SHIPPED_RE = ("shipped",)

# Lifecycle order for the Status column, most-committed first, so a customer
# reads the work Kong has actually promised before the work it hasn't looked at
# yet. Matched as a lowercased PREFIX, so financial-year-suffixed statuses
# ("Will not implement in FY27" -> "will not implement") keep sorting correctly
# when the FY rolls over. Anything unrecognised sorts last, alphabetically --
# a new Aha status is then merely out of order, never a crash.
STATUS_ORDER = (
    "planned",
    "under consideration",
    "needs review",
    "shipped",
    "will not implement",
)


def status_rank(status):
    s = (status or "").strip().lower()
    for i, known in enumerate(STATUS_ORDER):
        if s.startswith(known):
            return i
    return len(STATUS_ORDER)


def sort_key(item):
    """Status lifecycle first, then Stack Rank ascending within a status.

    Unranked ideas sort after ranked ones (mirrors fetch-ideas.sh's own
    ranked-then-unranked ordering), and ref breaks any remaining tie so the
    row order is stable between runs on identical data.
    """
    status = (item.get("status") or "").strip()
    raw_rank = item.get("rank")
    try:
        rank_value = float(raw_rank)
        rank_missing = False
    except (TypeError, ValueError):
        rank_value = 0.0
        rank_missing = True
    return (
        status_rank(status),
        status.lower(),
        rank_missing,
        rank_value,
        item.get("ref") or "",
    )


def font_face(family, weight, style, filename):
    return (
        f"@font-face {{ font-family: '{family}'; font-weight: {weight}; "
        f"font-style: {style}; src: url('file://{FONT_DIR}/{filename}') "
        f"format('truetype'); }}"
    )


FONT_FACES = "\n".join([
    font_face("Funnel Sans", 400, "normal", "funnel-sans/FunnelSans-Regular.ttf"),
    font_face("Funnel Sans", 700, "normal", "funnel-sans/FunnelSans-Bold.ttf"),
    font_face("Funnel Sans", 800, "normal", "funnel-sans/FunnelSans-ExtraBold.ttf"),
    font_face("Roboto Mono", 400, "normal", "roboto-mono/RobotoMono-Regular.ttf"),
])

# Kong 2026 v1.1 brand palette, interpolated into the CSS below as literal hex.
#
# These deliberately are NOT CSS custom properties. wkhtmltopdf's QtWebKit
# predates `var()` and drops any declaration using one: `color: var(--x)` is
# ignored, and `border: 1px solid var(--x)` is invalid so the whole border
# disappears. The report had been rendering with no lime badges, no section
# bars and no tile borders because of exactly that -- a greyscale PDF going to
# customers. Verified against wkhtmltopdf 0.12.6 by rendering a var() swatch
# next to a literal one: only the literal painted. Keep them literal.
KONG_DARK_GREEN = "#000F06"
KONG_ELECTRIC_LIME = "#CCFF00"
KONG_WHITE = "#FFFFFF"
KONG_NEUTRAL_100 = "#D7DED4"
KONG_NEUTRAL_300 = "#B7BDB5"
KONG_NEUTRAL_500 = "#858983"
KONG_NEUTRAL_700 = "#4A4D49"
KONG_NEUTRAL_900 = "#101110"

CSS = f"""
{FONT_FACES}

* {{ box-sizing: border-box; }}

body {{
  font-family: 'Funnel Sans', Helvetica, Arial, sans-serif;
  color: {KONG_NEUTRAL_900};
  background: {KONG_WHITE};
  margin: 0;
  padding: 32px 40px;
  font-size: 12px;
}}

/* Layout here is table-based, not flexbox, on purpose. This HTML is only ever
   rendered by wkhtmltopdf 0.12.6, whose QtWebKit engine silently ignores
   flexbox: `display: flex` children fall back to block and stack vertically.
   The header, the summary tiles, and the footer all looked fine in a browser
   and all came out stacked in the actual PDF. Tables render correctly there,
   so don't "modernise" these back to flex/grid without re-rendering a PDF and
   looking at it. */
.page-header {{
  width: 100%;
  border-bottom: 3px solid {KONG_DARK_GREEN};
  padding-bottom: 16px;
  margin-bottom: 24px;
  border-collapse: collapse;
}}

.page-header td {{
  border: none;
  padding: 0 0 16px 0;
  vertical-align: bottom;
}}

.page-header img {{ height: 28px; }}

.page-header td.meta {{ text-align: right; }}

h1 {{
  font-size: 24px;
  font-weight: 800;
  margin: 0 0 4px 0;
  color: {KONG_DARK_GREEN};
}}

.subtitle {{
  font-size: 12px;
  color: {KONG_NEUTRAL_700};
  margin: 0;
}}

/* One row of equal-width tiles across the full page width. table-layout:fixed
   keeps the four columns even regardless of how big the numbers get. */
.summary {{
  width: 100%;
  table-layout: fixed;
  border-collapse: separate;
  border-spacing: 10px 0;
  margin: 0 -10px 28px -10px;
}}

.summary td.stat {{
  border: 1px solid {KONG_NEUTRAL_300};
  border-radius: 6px;
  padding: 10px 16px;
  vertical-align: top;
  text-align: left;
}}

.stat .n {{
  font-size: 22px;
  font-weight: 800;
  color: {KONG_DARK_GREEN};
  line-height: 1.1;
}}

.stat .label {{
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: {KONG_NEUTRAL_700};
}}

h2 {{
  font-size: 14px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: {KONG_DARK_GREEN};
  border-left: 4px solid {KONG_ELECTRIC_LIME};
  padding-left: 8px;
  margin: 24px 0 10px 0;
}}

table {{
  width: 100%;
  border-collapse: collapse;
  margin-bottom: 8px;
}}

th {{
  text-align: left;
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: {KONG_NEUTRAL_700};
  border-bottom: 1px solid {KONG_NEUTRAL_300};
  padding: 6px 8px;
}}

td {{
  padding: 7px 8px;
  border-bottom: 1px solid {KONG_NEUTRAL_100};
  vertical-align: top;
}}

.badge {{
  display: inline-block;
  font-size: 9px;
  font-weight: 700;
  text-transform: uppercase;
  padding: 2px 7px;
  border-radius: 10px;
}}

.badge.open {{ background: {KONG_ELECTRIC_LIME}; color: {KONG_DARK_GREEN}; }}
.badge.closed {{ background: {KONG_NEUTRAL_100}; color: {KONG_NEUTRAL_700}; }}

.ref {{ font-family: 'Roboto Mono', monospace; font-size: 10px; color: {KONG_NEUTRAL_700}; }}

/* Status is a short fixed vocabulary, so let it claim the width it needs
   rather than wrapping "Under consideration" onto two lines. The tracking
   columns to its right are blank for most rows (the expected steady state
   until CSMs fill them in) and auto-layout otherwise hands that slack to
   them. */
td.status {{ white-space: nowrap; }}

.page-footer {{
  width: 100%;
  margin-top: 32px;
  border-top: 1px solid {KONG_NEUTRAL_300};
  font-size: 9px;
  color: {KONG_NEUTRAL_500};
  border-collapse: collapse;
}}

.page-footer td {{
  border: none;
  padding: 10px 0 0 0;
}}

.page-footer td.right {{ text-align: right; }}
"""


def esc(s):
    if s is None:
        return ""
    return (
        str(s)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def blocker_text(v):
    if v == 1 or v is True:
        return "Yes"
    if v == 0 or v is False:
        return "No"
    return ""


def rows_html(items):
    out = []
    for it in items:
        badge_cls = "open" if it.get("state") == "open" else "closed"
        badge_text = "Open" if it.get("state") == "open" else "Closed"
        rank = it.get("rank")
        out.append(
            "<tr>"
            f"<td><span class='badge {badge_cls}'>{badge_text}</span></td>"
            f"<td class='ref'>{esc(it.get('ref'))}</td>"
            f"<td>{esc(it.get('name'))}</td>"
            f"<td class='status'>{esc(it.get('status'))}</td>"
            f"<td>{esc(rank if rank is not None else '')}</td>"
            f"<td>{esc(it.get('use_case'))}</td>"
            f"<td>{esc(it.get('requester_name'))}</td>"
            f"<td>{esc(it.get('team_name'))}</td>"
            f"<td>{esc(blocker_text(it.get('production_blocker')))}</td>"
            f"<td>{esc(it.get('target_release'))}</td>"
            f"<td>{esc(it.get('notes'))}</td>"
            "</tr>"
        )
    return "\n".join(out)


def section(title, items):
    if not items:
        return ""
    headers = ("", "Ref", "Idea", "Status", "Stack Rank", "Use Case", "Requester", "Team",
               "Production Blocker", "Target Release", "Notes")
    head_html = "".join(f"<th>{esc(h)}</th>" for h in headers)
    return f"""
    <h2>{esc(title)} ({len(items)})</h2>
    <table>
      <thead><tr>{head_html}</tr></thead>
      <tbody>{rows_html(items)}</tbody>
    </table>
    """


CSV_HEADERS = [
    "State", "Ref", "Idea", "Status", "Stack Rank", "Use Case", "Requester",
    "Team", "Production Blocker", "Target Release", "Notes", "Source Link",
    "Internal Discussion Link",
]


def render_csv(open_items, closed_items):
    """Emit the customer-facing CSV to stdout.

    Same row ordering as the PDF -- the Open block first, then Closed, each
    already sorted by sort_key -- so the CSV and the PDF a customer receives
    always list ideas in the identical order. Columns mirror the PDF's data
    plus the two non-internal link columns (Source, Internal Discussion) as
    bare URLs; the Aha Link / Proxy Vote Link columns the internal Sheet
    carries are intentionally omitted, since this file goes to the customer.
    """
    writer = csv.writer(sys.stdout)
    writer.writerow(CSV_HEADERS)
    for it in open_items + closed_items:
        state = "Open" if it.get("state") == "open" else "Closed"
        rank = it.get("rank")
        writer.writerow([
            state,
            it.get("ref") or "",
            it.get("name") or "",
            it.get("status") or "",
            rank if rank is not None else "",
            it.get("use_case") or "",
            it.get("requester_name") or "",
            it.get("team_name") or "",
            blocker_text(it.get("production_blocker")),
            it.get("target_release") or "",
            it.get("notes") or "",
            it.get("source_url") or "",
            it.get("internal_discussion_url") or "",
        ])


def main():
    args = sys.argv[1:]
    fmt = "html"
    positional = []
    idx = 0
    while idx < len(args):
        arg = args[idx]
        if arg == "--format":
            if idx + 1 >= len(args):
                print("--format requires a value", file=sys.stderr)
                sys.exit(2)
            fmt = args[idx + 1]
            idx += 2
            continue
        positional.append(arg)
        idx += 1

    if len(positional) != 1 or fmt not in ("html", "csv"):
        print("usage: render_report.py [--format html|csv] CUSTOMER_NAME < ideas.json",
              file=sys.stderr)
        sys.exit(2)
    customer_name = positional[0]
    items = json.load(sys.stdin)

    open_items = sorted((i for i in items if i.get("state") == "open"), key=sort_key)
    closed_items = sorted((i for i in items if i.get("state") != "open"), key=sort_key)

    if fmt == "csv":
        render_csv(open_items, closed_items)
        return

    shipped = [i for i in closed_items if "shipped" in (i.get("status") or "").lower()]

    generated = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    html = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>{CSS}</style>
</head>
<body>
<table class="page-header"><tbody><tr>
  <td><img src="file://{LOGO}" alt="Kong"></td>
  <td class="meta">
    <h1>Feature Request Status</h1>
    <p class="subtitle">{esc(customer_name)} &middot; last generated {generated}</p>
  </td>
</tr></tbody></table>

<table class="summary"><tbody><tr>
  <td class="stat"><div class="n">{len(items)}</div><div class="label">Total</div></td>
  <td class="stat"><div class="n">{len(open_items)}</div><div class="label">Open</div></td>
  <td class="stat"><div class="n">{len(shipped)}</div><div class="label">Shipped</div></td>
  <td class="stat"><div class="n">{len(closed_items) - len(shipped)}</div><div class="label">Other closed</div></td>
</tr></tbody></table>

{section("Open", open_items)}
{section("Closed", closed_items)}

<table class="page-footer"><tbody><tr>
  <td>Kong Customer Success &middot; internal Aha! tracking</td>
  <td class="right">{esc(customer_name)} &middot; {generated}</td>
</tr></tbody></table>
</body>
</html>
"""
    print(html)


if __name__ == "__main__":
    main()
