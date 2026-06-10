---
name: wave-invoicing
description: Assemble a monthly Wave invoice for a consulting customer — pass-through credit-card chargebacks (no markup) plus consulting hours. Reads evidence PDFs/PNGs in the working dir and consulting hours from the prompt or a file, reconciles against the Insync invoice history to avoid duplicate/skipped billing, creates a DRAFT invoice in Wave, downloads the invoice PDF, renames + zips the evidence, and writes a humanized email body into a local folder. Use when the user says "wave invoicing", "create the monthly invoice", "bill Camino", "/wave-invoicing", or drops chargeback screenshots/PDFs and asks to invoice a customer. Does NOT send the email (the user sends it by hand) and leaves the Wave invoice as DRAFT.
---

# Wave Invoicing

All Wave API I/O goes through the scripts in `scripts/` — never hand-write `curl`.
Money is never trusted blind: always show the line-item table for approval before
creating anything. Any missing datum: ask the user.

## Writing discipline
ALL customer-facing prose this skill produces (the `email.md` cover note, and any
future note or message) goes through **both** writing skills before it is saved:
first the **writing-style** skill (the user's voice — Canadian English, "Cheers,"
sign-off), then the **humanizer** skill (strip AI tells). This applies to every
piece of writing, not just one step. Internal status reports to the user (e.g. the
Stage-1 working-folder summary) are exempt — they are not customer-facing.

## Secrets discipline
Auth uses a Wave **Full Access Token** (personal-use bearer token). It lives in
1Password (`op://nixerator/wave/credential`) and is exposed to the skill as the
`WAVE_FULL_ACCESS_TOKEN` env var via the nixerator claude-code module
(secrets.json.tpl → secrets.json → env, like `AHA_API_TOKEN`). The skill never
calls `op` at runtime. NEVER print, log, or surface the token (not even a prefix
or length); when verifying, rely on exit status only.

## Prerequisites (one-time)
The Wave I/O scripts (`wave-bootstrap.sh`, `wave-create-invoice.sh`,
`wave-download-pdf.sh`) need this setup before they work:
1. In the Wave developer portal (developer.waveapps.com) → Manage Applications →
   create an application → **Create token** to generate a **Full Access Token**.
2. Put the token in the 1Password `nixerator` vault, item `wave`, field
   `credential` (`op://nixerator/wave/credential`).
3. Run `just render-secrets` then rebuild (`just qr`) so `WAVE_FULL_ACCESS_TOKEN`
   is in the environment.
4. In Wave, create products "Consulting" and "Reimbursable Expenses".
5. Run `scripts/wave-bootstrap.sh` and copy the returned ids into `config.json`
   (`wave.business_id`, `customers.camino.wave_customer_id`, `wave.products.*`).
If the Wave id fields in `config.json` are empty, do steps 1–5 before Stage 1.

## Config
`config.json` holds the issuer (`BrMfg` = Bashfulrobot Manufacturing), the
customer (`Camino Corp`), Wave ids, the vendor-code map, and paths. Read values
with `source scripts/lib.sh config.json; cfg '.path'`.

## Stage Q — Status / freeform query (read-only fast path)
For any "do I have outstanding invoices?", "what's overdue?", "did Camino pay
the May invoice?" question, do NOT improvise a GraphQL query or run
`wave-bootstrap.sh`. Run `scripts/wave-list-invoices.sh [CONFIG] [STATUS]` — it
returns normalized JSON (real-number amounts, plus `outstanding` and `overdue`
booleans) so you answer with one `jq` select, e.g.
`scripts/wave-list-invoices.sh | jq 'map(select(.outstanding))'`. Pass an
optional STATUS (e.g. `OVERDUE`, `PAID`, `UNVERIFIED`) to filter server-side.
Needs `wave.business_id` populated (Stage-1 prerequisites). Read-only — never
creates or mutates anything.

## Workflow

### Stage 0 — Reconcile (catch-up guard)
1. Determine the target period (`YYYY-MM`) — ask if unclear.
2. Run `scripts/reconcile.sh "$(cfg '.customers.camino.insync_root')" "$(cfg '.issuer.code')" <PERIOD>`.
3. Present the summary: last billed period, last sequence, billed periods, gaps.
   - If `targetAlreadyBilled` is true → STOP and warn (duplicate billing).
   - If there are `gaps` → ask whether to catch them up or skip.
4. The next sequence is `lastSeq + 1` for the target period (or `1` if none yet).

### Stage 1 — Assemble (local working folder)
5. Create a local working dir (NOT in Insync), e.g. `./wave-run-<PERIOD>/`.
6. Scan the working dir for evidence (`*.pdf`, `*.png`). For each, read it (vision)
   and propose `{vendor, amount, description}`. Map vendor → code via
   `.customers.camino.vendors`. Ask the user to confirm/correct every amount.
7. Gather consulting hours: from the prompt or a file the user names. Each line:
   `description / hours / rate` (default rate `.customers.camino.default_rate`).
8. Present the full line-item table (consulting + pass-through) and get explicit approval.
9. Build the invoice number: `scripts/naming.sh number <PERIOD> <SEQ>`.
10. Build line items JSON: consulting items use `products.consulting`
    (`quantity`=hours, `price`=rate); pass-through items use `products.passthrough`
    (`quantity`=1, `price`=amount). Then in one shell:
    `source scripts/lib.sh config.json; build_invoice_payload <BIZ> <CUST> <NUMBER> <INVOICE_DATE> <DUE_DATE> <ITEMS>` > payload.json
    (ask for invoice date / due terms; default due = invoice date + 30d).
11. Create the DRAFT: `scripts/wave-create-invoice.sh payload.json` → capture `pdfUrl` + `invoiceNumber`.
12. Derive filenames: `scripts/naming.sh files <ISSUER> <PERIOD> <SEQ> <VENDORCODES...>`.
13. Download the PDF: `scripts/wave-download-pdf.sh <pdfUrl> <workdir>/<invoicePdf>`.
14. Package evidence: build the `{source:vendorcode}` map and run
    `scripts/package-evidence.sh <workdir> <PERIOD> <ISSUER> <MAP_JSON>`.
15. Write `email.md` (cover note to the customer). Per **Writing discipline**
    above, run it through the **writing-style** then **humanizer** skills before
    saving.
16. Report the working folder contents and STOP: tell the user to review, then send
    the Gmail by hand (attach the invoice PDF + the references zip, paste `email.md`).

### Stage 2 — File it (offer)
17. After the user confirms the email is sent, OFFER to copy the artifacts into
    `<insync_root>/<folder>/` (from `naming.sh files .folder`). Only copy on
    explicit confirmation. Never write to Insync before the email is sent.
