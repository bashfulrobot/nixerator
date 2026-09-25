# Wave GraphQL — queries/mutations used by this skill

Endpoint: `https://gql.waveapps.com/graphql/public` (POST, `Authorization: Bearer <token>`).

## Authentication — Full Access Token (personal use)
This skill authenticates with a Wave **Full Access Token**, not OAuth. Wave's docs
recommend the Full Access Token for "development purposes or personal applications
only" (OAuth is required only for apps distributed to other users). It is a
long-lived bearer token (~3-year expiry) created in the developer portal
(Manage Applications → an application → **Create token**).

The token lives in 1Password (`op://nixerator/wave/credential`) and reaches the
skill as the `WAVE_FULL_ACCESS_TOKEN` env var via the nixerator claude-code module
(secrets.json.tpl → secrets.json → env). No OAuth client id/secret/refresh flow.

## Secrets discipline
The token is a secret. It is read from `WAVE_FULL_ACCESS_TOKEN` and used only in
the `Authorization: Bearer` header — never printed, logged, or returned to a
terminal. There is intentionally no CLI that prints it. See the
`wave_access_token` note in `scripts/lib.sh`.

## Bootstrap query (businesses → customers + products)
See `scripts/wave-bootstrap.sh`. Returns the ids needed in `config.json`
(`wave.business_id`, `customers.<c>.wave_customer_id`, `wave.products.*`).

## invoices (read-only status query)
See `scripts/wave-list-invoices.sh`. Queries
`business(id).invoices(page,pageSize,status)` and returns a normalized JSON array
(amounts coerced to numbers, plus computed `outstanding` and `overdue` flags) so
freeform status questions resolve with a single `jq` select instead of an
ad-hoc query. The optional `status` arg (enum `InvoiceStatus`, e.g. `DRAFT`,
`SAVED`, `SENT`, `PAID`, `OVERDUE`) filters server-side. Schema verified against
the live API 2026-06-10 (arg `status`, money `.value`); observed status values
include `SENT` (outstanding) and `PAID`.

## invoiceCreate
Input `InvoiceCreateInput`: `businessId`, `customerId`, `status` (DRAFT),
`invoiceNumber`, `invoiceDate`, `dueDate`,
`items: [{ productId, description, quantity, unitPrice }]` (verified via
introspection 2026-09-24; the field is `unitPrice`, not `price`).
Selection: `didSucceed`, `inputErrors{message,code,path}`,
`invoice{ id pdfUrl viewUrl invoiceNumber status }`.
Invoices default to DRAFT; `wave-create-invoice.sh` never sends/finalizes them.
Line items REQUIRE a `productId` — create "Consulting" and "Reimbursable
Expenses" products in Wave and record their ids in `config.json`.

## invoiceApprove (see `scripts/wave-invoice-approve.sh`)
Input `InvoiceApproveInput`: `invoiceId` only. Moves a DRAFT invoice to
Approved/Saved. Does not notify the customer in any way — verified via
introspection 2026-09-24. Selection: `didSucceed`, `inputErrors`,
`invoice{ id invoiceNumber status }`.

## invoiceMarkSent (see `scripts/wave-invoice-mark-sent.sh`)
Input `InvoiceMarkSentInput`: `invoiceId`, `sendMethod` (enum
`InvoiceSendMethod`), optional `sentAt` (DateTime). Records the invoice as
sent in Wave's own bookkeeping — it does **not** deliver anything; Wave sends
no email for this mutation. `sendMethod: MARKED_SENT` is the right value when
delivery happened outside Wave (e.g. the user emailed the PDF from Gmail
themselves, which is this skill's whole model). Other enum values observed:
`EXPORT_PDF`, `GMAIL`, `NOT_SENT`, `OUTLOOK`, `SHARED_LINK`, `SKIPPED`,
`WAVE`, `YAHOO`. Selection: `didSucceed`, `inputErrors`,
`invoice{ id invoiceNumber status }`.

## invoiceSend — deliberately NOT wrapped
Input `InvoiceSendInput` (`invoiceId`, `to`, `subject`, `message`,
`attachPDF`, `fromAddress`, `ccMyself`) has Wave itself email the invoice to
the customer. That conflicts with this skill's model, where the user sends
their own cover email (`email.md`) by hand. No script calls this mutation —
don't add one without an explicit ask, since it changes who the customer
hears from.
