# Wave GraphQL — queries/mutations used by this skill

Endpoint: `https://gql.waveapps.com/graphql/public` (POST, `Authorization: Bearer <token>`).
OAuth token endpoint: `https://api.waveapps.com/oauth2/token/`.

## Refresh token → access token
POST form: `client_id`, `client_secret`, `grant_type=refresh_token`, `refresh_token`.
Response: `{ access_token, token_type:"Bearer", expires_in, refresh_token }`.

`UNVERIFIED:` whether Wave rotates the refresh token on each refresh. The OAuth
docs describe access-token invalidation on refresh but do not mention refresh-token
rotation, so the read-only 1Password approach is very likely fine. Confirm by
running a token exchange twice (exit-status only — never print the token).

## Secrets discipline
The access token and the `op://` credential fields are secrets. They are read and
used only inside the scripts (Authorization header / curl form body) and are never
printed to stdout, logged, or returned to a terminal. There is intentionally no
CLI that prints the token. See the `wave_access_token` note in `scripts/lib.sh`.

## Bootstrap query (businesses → customers + products)
See `scripts/wave-bootstrap.sh`. Returns the ids needed in `config.json`
(`wave.business_id`, `customers.<c>.wave_customer_id`, `wave.products.*`).

## invoiceCreate
Input `InvoiceCreateInput`: `businessId`, `customerId`, `status` (DRAFT),
`invoiceNumber`, `invoiceDate`, `dueDate`,
`items: [{ productId, description, quantity, price }]`.
Selection: `didSucceed`, `inputErrors{message,code,path}`,
`invoice{ id pdfUrl viewUrl invoiceNumber status }`.
Invoices default to DRAFT; this skill never sends/finalizes them.
Line items REQUIRE a `productId` — create "Consulting" and "Reimbursable
Expenses" products in Wave and record their ids in `config.json`.
