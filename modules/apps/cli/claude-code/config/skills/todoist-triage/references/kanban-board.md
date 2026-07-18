# Kanban board: columns, routing, and freshness

Dustin's Kong customer work lives on Todoist **board-view** projects, one per
account, each with the same fixed set of columns (Todoist *sections*). Part of a
triage assessment is putting a task in the **right column** — the column is a
first-class status signal, so a task sitting in the wrong one is exactly the kind
of stale-state this skill exists to catch. This file is the durable reference for
what the columns mean and which one a task belongs in. The *move* mechanics live
in `macros.md` (`move` verb); this file owns the *policy* of which column.

## Which projects have columns

Board columns exist **only on the `Kong*` projects** (`Kong`, `Kong-lululemon`,
`Kong-standard`, `Kong-paypal`, `Kong-x.ai`, `Kong-zillow`, `Kong-nordstrom`,
`Kong-health-equity`, `Kong-sony`, `Kong-world-labs`, `Kong-cs`, …) plus the
`template` project they're cloned from. A new account shows up as a new
`Kong-<customer>` project and **inherits the canonical columns below by
construction** — that is the point of the pattern: new customers are covered
automatically, never "missed" because they weren't in a list. Non-`Kong`
projects (personal, home, etc.) have no sections; `move` does not apply there.

## The canonical columns (what each means, when a task routes there)

Names are stable and identical across projects; only the section *ids* differ per
project, and `td task move <ref> --section "<name>"` resolves the name within the
task's own project, so the name is all the routing logic needs.

| Column | What it means | Route a task here when the assessment says… |
|---|---|---|
| **Reoccurring** | Recurring cadence tasks (account hygiene, standing check-ins). | Never auto-move. Recurring tasks manage their own place. |
| **Backlog** | Captured, acknowledged, not yet prioritized. | `on-track`/`stale` with no live thread and no near-term commitment — real but not queued. |
| **Up Next** | Prioritized, work it next; ball is on Dustin. | `ball_owner: me`, actionable now/soon, nothing external blocking. |
| **Needs Action** | **Ball is on Dustin** — he's the bottleneck; a concrete next step is his to take. | `ball_owner: me` where Dustin (not another Konger) owes the move. Distinct from `Up Next`, which is "queued to work"; `Needs Action` is "surfaced because the last activity put the ball back on him". |
| **Capture Data** | **A documentation task**: take the info source named in the task and write it up or relocate it to a durable home — a Confluence article, a doc, the customer notes dir, etc. The deliverable is captured knowledge, not a customer nudge. | `next_action` is "document / move this into <destination>", ball on Dustin, and the work is transcribe/relocate rather than research-then-reply. Name the destination in `next_action` when known. |
| **Meetings** | Meeting prep and meeting-driven tasks. | The task is prep for, or an output of, a specific meeting. |
| **Waiting Internal** | Blocked on a **Kong-internal** person or team. | `waiting-on-them` where "them" is internal (SE, PM, support engineer, another Konger). |
| **Waiting Customer** | Blocked on the **customer**. | `waiting-on-them` where "them" is a customer-side contact. |
| **Waiting Validation** | Delivered; waiting for confirmation/sign-off before it can close. | `likely-done` pending someone's confirmation — the work is done, the close is gated on a yes. |
| **! Customer Blocker** | Actively blocking the customer; escalation-grade. | `blocked` **and** customer-impacting — something the customer is stuck behind. Higher urgency than a plain wait. |
| **FRs** | Feature-request tracking. | The task is (or becomes) a feature request — hand to the `feature-request` / `log-aha` flow and place here. |
| **Engineering** | Handed to / tracking Kong engineering. | The next move sits with Kong eng (a bug, an escalation, a fix in flight). |
| **Review** | *(general `Kong` project only)* awaiting review. | Ready for or under review, on the general `Kong` board. |

**Internal vs customer** is the split between `Waiting Internal` and `Waiting
Customer`, and the subagent already establishes who owes the next move — reuse
that: if the person the ball sits with is a Konger, it's `Waiting Internal`; a
customer-side contact, `Waiting Customer`. When genuinely unsure, leave the
column unchanged and say so in `unverified[]` rather than guessing a move.

## Ball-owner → column (the auto-move mapping)

The one action the skill takes on its own. The model classifies the ball-owner
from the work-log prose; this mapping is deterministic (`td_autocolumn.sh`):

| Ball owner | Column |
|---|---|
| customer-side contact | `Waiting Customer` |
| Kong-internal person/team (not Dustin) | `Waiting Internal` |
| Dustin owes the next move | `Needs Action` |
| delivered, awaiting sign-off | `Waiting Validation` |

**Disambiguate `me` from another Konger.** If Dustin is one of the actors who
owes the move → `Needs Action`; if it sits purely with another Kong person/team →
`Waiting Internal`. When the wording blurs the two ("the Kong side
(me/Christian)"), leave the column unmoved and say so — never guess. No ball-owner
signal (empty log) → no move.

## Recommend, flag the mismatch, never auto-move

- The subagent fills `current_column` (where the task is now) and
  `recommended_column` (where the assessment says it belongs) for every
  `Kong*`-board task.
- When they differ, that mismatch is a triage signal — surface it on the card
  ("in `Up Next`, but it's been `waiting-on-them` 12d → `Waiting Customer`").
- The actual move is the `move` verb, in the **internal-batched** gate tier
  (reversible, touches nobody outward): shown per-task in the walk, then run on
  one approval alongside `note`/`defer`. Never move a column silently.

## Known deviations (don't cache a snapshot — see below)

- **General `Kong`** adds a `Review` column and has no `Engineering`.
- **`Kong-cs`** is a 7-column subset (no `Waiting Customer`, `! Customer
  Blocker`, `FRs`, or `Engineering`) — it's internal CS work.
- **`Needs Action`** was added to every `Kong*` board + `template` (see
  `scripts/create_needs_action.sh`). A newly-cloned `Kong-<customer>` inherits it
  from `template` by construction.

If a `recommended_column` doesn't exist in a task's project (e.g. recommending
`Waiting Customer` on `Kong-cs`), the move will fail — fall back to the nearest
valid column (`Waiting Internal` there) or leave it and note it. The **live**
`td section list "<project>"` is the source of truth for a project's actual
columns; consult it when a move is in doubt, not a cached list.

## Caching and freshness

The genuinely-useful caching for this skill already exists — reuse it, don't
build a parallel board cache:

- **Stable per-customer identifiers** (Slack channel, notes dir, contacts,
  routing) live in the `skill-cache` `customers`/`contacts`/`routing` tables per
  `source-resolution.md`. That is where a customer's durable facts belong.
- **Todoist project / section ids** are owned by the `todoist-cli` skill's
  `todoist` id cache; `td` resolves and caches them. Don't duplicate ids here.
- **The column vocabulary + semantics** (this file) are durable reference, not a
  cache — they change rarely, and hard-coding them is *why* a new `Kong-<customer>`
  can't be missed: it inherits them by pattern.

The freshness rule, so a cache never hides new data: **a cache accelerates, it
never decides existence.** On a miss — a customer or project not seen before —
resolve it live and let the existing cache pick it up; a new account is handled
the first time a task from it is triaged, not whenever a list was last rebuilt.
Never cache a per-project column *snapshot*: that is precisely what would silently
miss a board someone re-columned. Live-list when a move is in doubt; otherwise
trust the canonical set above.
