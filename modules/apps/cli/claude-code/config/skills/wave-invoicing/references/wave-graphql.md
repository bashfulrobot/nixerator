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
ad-hoc query. The optional `status` arg (enum `InvoiceStatus`, e.g. `SAVED`,
`UNVERIFIED`, `PAID`, `OVERDUE`, `DRAFT`) filters server-side. UNVERIFIED: the
exact arg/enum/money-field names follow Wave's public schema but were not
confirmed live; adjust the query in the script if a field errors.

## invoiceCreate
Input `InvoiceCreateInput`: `businessId`, `customerId`, `status` (DRAFT),
`invoiceNumber`, `invoiceDate`, `dueDate`,
`items: [{ productId, description, quantity, price }]`.
Selection: `didSucceed`, `inputErrors{message,code,path}`,
`invoice{ id pdfUrl viewUrl invoiceNumber status }`.
Invoices default to DRAFT; this skill never sends/finalizes them.
Line items REQUIRE a `productId` — create "Consulting" and "Reimbursable
Expenses" products in Wave and record their ids in `config.json`.
