#!/usr/bin/env python3
"""Render a customer's Aha! feature-request list into a Kong-branded,
self-contained HTML report (White theme, print-friendly). Meant to be piped
into wkhtmltopdf immediately after; every asset is referenced by local
file:// path (fonts, logo), so the HTML only needs to survive long enough to
be rendered on this machine.

Usage:
    render_report.py CUSTOMER_NAME < ideas.json > report.html
"""
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

CSS = f"""
{FONT_FACES}

:root {{
  --kong-dark-green: #000F06;
  --kong-electric-lime: #CCFF00;
  --kong-bay: #B7BDB5;
  --kong-white: #FFFFFF;
  --kong-neutral-100: #D7DED4;
  --kong-neutral-300: #B7BDB5;
  --kong-neutral-500: #858983;
  --kong-neutral-700: #4A4D49;
  --kong-neutral-900: #101110;
}}

* {{ box-sizing: border-box; }}

body {{
  font-family: 'Funnel Sans', Helvetica, Arial, sans-serif;
  color: var(--kong-neutral-900);
  background: var(--kong-white);
  margin: 0;
  padding: 32px 40px;
  font-size: 12px;
}}

header {{
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  border-bottom: 3px solid var(--kong-dark-green);
  padding-bottom: 16px;
  margin-bottom: 24px;
}}

header img {{ height: 28px; }}

header .meta {{ text-align: right; }}

h1 {{
  font-size: 24px;
  font-weight: 800;
  margin: 0 0 4px 0;
  color: var(--kong-dark-green);
}}

.subtitle {{
  font-size: 12px;
  color: var(--kong-neutral-700);
  margin: 0;
}}

.summary {{
  display: flex;
  gap: 24px;
  margin-bottom: 28px;
}}

.stat {{
  border: 1px solid var(--kong-neutral-300);
  border-radius: 6px;
  padding: 10px 16px;
  min-width: 90px;
}}

.stat .n {{
  font-size: 22px;
  font-weight: 800;
  color: var(--kong-dark-green);
}}

.stat .label {{
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--kong-neutral-700);
}}

h2 {{
  font-size: 14px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--kong-dark-green);
  border-left: 4px solid var(--kong-electric-lime);
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
  color: var(--kong-neutral-700);
  border-bottom: 1px solid var(--kong-neutral-300);
  padding: 6px 8px;
}}

td {{
  padding: 7px 8px;
  border-bottom: 1px solid var(--kong-neutral-100);
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

.badge.open {{ background: var(--kong-electric-lime); color: var(--kong-dark-green); }}
.badge.closed {{ background: var(--kong-neutral-100); color: var(--kong-neutral-700); }}

.ref {{ font-family: 'Roboto Mono', monospace; font-size: 10px; color: var(--kong-neutral-700); }}

footer {{
  margin-top: 32px;
  padding-top: 10px;
  border-top: 1px solid var(--kong-neutral-300);
  font-size: 9px;
  color: var(--kong-neutral-500);
  display: flex;
  justify-content: space-between;
}}
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
            f"<td>{esc(it.get('status'))}</td>"
            f"<td>{esc(rank if rank is not None else '')}</td>"
            f"<td>{esc(it.get('total_endorsements'))}</td>"
            "</tr>"
        )
    return "\n".join(out)


def section(title, items):
    if not items:
        return ""
    return f"""
    <h2>{esc(title)} ({len(items)})</h2>
    <table>
      <thead><tr><th></th><th>Ref</th><th>Idea</th><th>Status</th><th>Stack Rank</th><th>Total votes</th></tr></thead>
      <tbody>{rows_html(items)}</tbody>
    </table>
    """


def main():
    if len(sys.argv) != 2:
        print("usage: render_report.py CUSTOMER_NAME < ideas.json", file=sys.stderr)
        sys.exit(2)
    customer_name = sys.argv[1]
    items = json.load(sys.stdin)

    open_items = [i for i in items if i.get("state") == "open"]
    closed_items = [i for i in items if i.get("state") != "open"]
    shipped = [i for i in closed_items if "shipped" in (i.get("status") or "").lower()]

    generated = datetime.date.today().isoformat()

    html = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>{CSS}</style>
</head>
<body>
<header>
  <img src="file://{LOGO}" alt="Kong">
  <div class="meta">
    <h1>Feature Request Status</h1>
    <p class="subtitle">{esc(customer_name)} &middot; generated {generated}</p>
  </div>
</header>

<div class="summary">
  <div class="stat"><div class="n">{len(items)}</div><div class="label">Total</div></div>
  <div class="stat"><div class="n">{len(open_items)}</div><div class="label">Open</div></div>
  <div class="stat"><div class="n">{len(shipped)}</div><div class="label">Shipped</div></div>
  <div class="stat"><div class="n">{len(closed_items) - len(shipped)}</div><div class="label">Other closed</div></div>
</div>

{section("Open", open_items)}
{section("Closed", closed_items)}

<footer>
  <span>Kong Customer Success &middot; internal Aha! tracking</span>
  <span>{esc(customer_name)} &middot; {generated}</span>
</footer>
</body>
</html>
"""
    print(html)


if __name__ == "__main__":
    main()
