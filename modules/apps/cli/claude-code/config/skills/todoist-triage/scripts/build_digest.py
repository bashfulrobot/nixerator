#!/usr/bin/env python3
"""build_digest.py — render a batch of triage assessments into a phone-skimmable
HTML digest.

Input: a JSON array of assessment objects (the schema in
references/assessment-schema.md), on stdin or as a file argument.
Output: a self-contained HTML file (theme-aware, groups + ball-owner/staleness
sort baked in). Prints the output path.

Usage:
    td_scope.sh ... | ... > batch.json
    build_digest.py batch.json [-o digest.html]
    cat batch.json | build_digest.py
"""
import argparse
import html
import json
import sys

# Group order = what Dustin does with each. (status set) -> (key, label).
GROUPS = [
    ("nudge",    "Nudge ready"),
    ("waiting",  "Waiting on others"),
    ("decision", "Needs a decision"),
    ("closeable","Closeable / likely done"),
    ("correction","Data correction"),
    ("other",    "Other"),
]


def group_of(a: dict) -> str:
    # Precedence: a wrong reference or a likely-done task is its own group
    # regardless of any draft; otherwise a ready-to-send draft is the actionable
    # "nudge" group (even if the ball is with them); then plain waiting/decision.
    status = (a.get("status") or "").lower()
    if status == "wrong-or-stale-reference":
        return "correction"
    if status == "likely-done":
        return "closeable"
    if a.get("draft_ready") and a.get("action_type") in (
        "draft-email", "prepare-slack", "post-comment"):
        return "nudge"
    if status == "waiting-on-them":
        return "waiting"
    if status in ("blocked", "waiting-on-me"):
        return "decision"
    return "other"


def sort_key(a: dict):
    # ball-owner + staleness: 'them' first, then largest days_silent.
    owner_rank = {"them": 0, "unknown": 1, "me": 2, "nobody": 3}
    return (owner_rank.get((a.get("ball_owner") or "unknown").lower(), 1),
            -int(a.get("days_silent") or 0))


def esc(x) -> str:
    return html.escape("" if x is None else str(x))


def card(a: dict) -> str:
    srcs = "".join(
        f"<li><b>{esc(s.get('source'))}</b>: {esc(s.get('citation'))}</li>"
        for s in a.get("sources", []))
    unver = "".join(f"<li>{esc(u)}</li>" for u in a.get("unverified", []))
    unver_block = f'<div class="unver"><b>Unverified</b><ul>{unver}</ul></div>' if unver else ""
    ctx_rows = "".join(
        f'<div class="ctxline"><span class="who">{esc(c.get("who"))}</span>'
        f'<span class="when">{esc(c.get("when"))}</span>'
        f'<span class="ex">{esc(c.get("excerpt"))}</span></div>'
        for c in a.get("recent_context", []))
    ctx_block = f'<div class="ctx"><b>Last word</b>{ctx_rows}</div>' if ctx_rows else ""
    conf = esc(a.get("confidence"))
    days = a.get("days_silent")
    stale = f'<span class="pill stale">{esc(days)}d silent</span>' if days else ""
    return f"""
    <article class="card conf-{conf}">
      <header>
        <span class="pill prio">{esc(a.get('priority'))}</span>
        <span class="pill">{esc(a.get('project'))}</span>
        <span class="pill owner-{esc(a.get('ball_owner'))}">{esc(a.get('ball_owner'))}</span>
        {stale}
        <span class="pill due">{esc(a.get('due') or 'no date')}</span>
      </header>
      <h3><a href="{esc(a.get('url') or '#')}">{esc(a.get('title'))}</a></h3>
      <p class="what">{esc(a.get('what_it_is'))}</p>
      <p class="next"><b>Next:</b> {esc(a.get('next_action'))}
         <span class="pill act">{esc(a.get('action_type'))}</span>
         <span class="pill conf">conf: {conf}</span></p>
      {ctx_block}
      <details><summary>sources</summary><ul>{srcs}</ul>{unver_block}</details>
    </article>"""


CSS = """
:root{--bg:#fff;--fg:#1a1a1a;--mut:#666;--line:#e3e3e3;--card:#fafafa;--accent:#c8102e}
@media(prefers-color-scheme:dark){:root{--bg:#15161a;--fg:#e8e8ea;--mut:#9aa;--line:#2c2e36;--card:#1d1f26}}
:root[data-theme=dark]{--bg:#15161a;--fg:#e8e8ea;--mut:#9aa;--line:#2c2e36;--card:#1d1f26}
:root[data-theme=light]{--bg:#fff;--fg:#1a1a1a;--mut:#666;--line:#e3e3e3;--card:#fafafa}
*{box-sizing:border-box}body{margin:0;padding:1rem;max-width:900px;margin:0 auto;
 background:var(--bg);color:var(--fg);font:15px/1.5 -apple-system,system-ui,sans-serif}
h1{font-size:1.3rem}h2{font-size:1rem;text-transform:uppercase;letter-spacing:.04em;
 color:var(--mut);border-bottom:1px solid var(--line);padding-bottom:.3rem;margin-top:1.8rem}
h3{font-size:1rem;margin:.4rem 0}a{color:inherit}
.card{background:var(--card);border:1px solid var(--line);border-left:3px solid var(--accent);
 border-radius:8px;padding:.7rem .9rem;margin:.6rem 0}
.card.conf-low{border-left-color:#e0a800}
header{display:flex;flex-wrap:wrap;gap:.35rem;align-items:center}
.pill{font-size:.72rem;padding:.1rem .45rem;border-radius:999px;background:var(--line);color:var(--fg)}
.pill.prio{font-weight:700}.pill.owner-them{background:#c8102e;color:#fff}
.pill.owner-me{background:#0a7d3c;color:#fff}.pill.stale{background:#e0a800;color:#111}
.what{color:var(--fg)}.next{margin:.3rem 0}.unver{color:#e0a800;font-size:.85rem}
.ctx{font-size:.82rem;border-left:2px solid var(--line);padding:.15rem 0 .15rem .5rem;margin:.3rem 0;color:var(--mut)}
.ctx b{display:block;text-transform:uppercase;letter-spacing:.03em;font-size:.7rem;margin-bottom:.15rem}
.ctxline{margin:.1rem 0}.ctxline .who{font-weight:600;color:var(--fg)}.ctxline .when{margin:0 .4rem;opacity:.7}
.ctxline .ex{font-style:italic}
details{margin-top:.3rem;font-size:.85rem;color:var(--mut)}summary{cursor:pointer}
.empty{color:var(--mut);font-style:italic}
"""


def render(items):
    items = [a for a in items if isinstance(a, dict)]
    buckets = {k: [] for k, _ in GROUPS}
    for a in items:
        buckets[group_of(a)].append(a)
    sections = []
    for key, label in GROUPS:
        rows = sorted(buckets[key], key=sort_key)
        if not rows:
            continue
        cards = "".join(card(a) for a in rows)
        sections.append(f"<section><h2>{esc(label)} ({len(rows)})</h2>{cards}</section>")
    body = "".join(sections) or '<p class="empty">No tasks in this batch.</p>'
    return f"""<!doctype html><html><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>Todoist triage digest</title><style>{CSS}</style></head><body>
<h1>Triage digest <span class=pill>{len(items)} tasks</span></h1>{body}</body></html>"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input", nargs="?", help="JSON file; omit to read stdin")
    ap.add_argument("-o", "--output", default="triage-digest.html")
    args = ap.parse_args()
    raw = open(args.input).read() if args.input else sys.stdin.read()
    data = json.loads(raw)
    if isinstance(data, dict):
        data = data.get("results") or data.get("assessments") or [data]
    with open(args.output, "w") as f:
        f.write(render(data))
    print(args.output)


if __name__ == "__main__":
    main()
