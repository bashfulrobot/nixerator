# Aha! API reference

Catalogue of endpoints, query params, pagination, rate limits, and field
selection for the Aha! v1 REST API. Source: https://www.aha.io/api (verified
2026-06-09). Anything marked UNVERIFIED was inferred from the docs index and
should be confirmed by GETting one record before relying on it.

All calls go through `scripts/aha.sh`; paths below are relative to
`https://konghq.aha.io/api/v1/`.

## Base URL & auth

- Base: `https://<subdomain>.aha.io/api/v1/` (default subdomain `konghq`).
- Auth: `Authorization: Bearer <token>`. The script supplies this from the
  `AHA_API_TOKEN` environment variable.
- Personal API keys are generated in the Aha! UI at
  `https://secure.aha.io/settings/api_keys`. A key keeps working across the
  user's password changes; it carries that user's permissions.
- Responses are JSON. Errors use standard HTTP status codes (401 bad/missing
  token, 403 forbidden, 404 not found, 422 validation, 429 rate limited).

## Reference-number shapes

The prefix is the product key (e.g. `DEVP`). The infix encodes the type:

| Shape            | Type        | Example      | GET path                  |
|------------------|-------------|--------------|---------------------------|
| `PREFIX-<n>`     | feature     | `DEVP-123`   | `features/DEVP-123`       |
| `PREFIX-E-<n>`   | epic        | `DEVP-E-8`   | `epics/DEVP-E-8`          |
| `PREFIX-I-<n>`   | idea        | `DEVP-I-42`  | `ideas/DEVP-I-42`         |
| `PREFIX-R-<n>`   | requirement | `DEVP-R-9`   | `requirements/DEVP-R-9`   |

You can GET any record by its reference number directly -- no internal id
lookup needed.

## Resource catalogue

Singular GET by reference works for each; list endpoints are usually scoped to
a product (`products/<PREFIX>/<collection>`).

| Resource     | Get one                     | List (scoped)                       | Create            |
|--------------|-----------------------------|-------------------------------------|-------------------|
| Features     | `features/{ref}`            | `products/{prod}/features`          | `releases/{ref}/features` or `features` |
| Ideas        | `ideas/{ref}`               | `products/{prod}/ideas`             | `ideas` (or `products/{prod}/ideas`) |
| Epics        | `epics/{ref}`               | `products/{prod}/epics`             | `releases/{ref}/epics` |
| Initiatives  | `initiatives/{ref}`         | `products/{prod}/initiatives`       | `initiatives` UNVERIFIED |
| Releases     | `releases/{ref}`            | `products/{prod}/releases`          | `products/{prod}/releases` |
| Requirements | `requirements/{ref}`        | (via parent feature)                | `features/{ref}/requirements` |
| Goals        | `goals/{id}`                | `products/{prod}/goals`             | `products/{prod}/goals` UNVERIFIED |
| Products     | `products/{prod}`           | `products`                          | n/a |
| Comments     | n/a                         | `<resource>/{ref}/comments`         | `<resource>/{ref}/comments` |
| Endorsements | `ideas/{ref}/endorsements/{id}` | `ideas/{ref}/endorsements`      | `ideas/{ref}/endorsements` (proxy vote; body keyed `idea_endorsement`, dollar field `value`) |
| Users        | `users/{id}`                | `users`                             | n/a |

Verified live: `epics/{ref}` and `products/{prod}/features` (2026-06-09);
`products/{prod}/ideas` create, `ideas/{ref}/endorsements` create + list +
get-one, and `idea_organizations` search/get (2026-06-15). Treat the rest as the
documented shape and confirm by GETting one record.

Note on writes: a reviewer-role token can create ideas and endorsements but gets
`403` on PUT/DELETE of an endorsement (observed 2026-06-15), and endorsement
`email`/custom fields are create-time, so there is no clean API undo. Get the
body right on the first POST.

## Common query params (list endpoints)

Passed with `-q 'key=value'` (repeatable; the script URL-encodes values, so
spaces in `q=` are fine):

- `q` -- full-text search term.
- `fields` -- comma-separated field allow-list, e.g.
  `fields=reference_num,name,workflow_status`. Use `fields=*` for everything.
  Always set this on reads to keep payloads small and readable.
- `updated_since` / `created_since` -- ISO 8601 timestamp filter.
- `tag` -- filter by tag.
- `assigned_to_user` -- filter by assignee (id or email) UNVERIFIED.
- Ideas-specific: `category`, `workflow_status`, `spam`, `sort` UNVERIFIED --
  confirm against the live response before depending on them.

## Pagination

- 1-indexed. Default page size 30; max 200. The script defaults `--per-page`
  to 100.
- Response carries a `pagination` object: `total_records`, `total_pages`,
  `current_page`.
- `scripts/aha.sh --paginate` walks every page and merges the collection array
  (features, ideas, ...) into one flat JSON array. It re-reads `total_pages`
  each page and sleeps 0.1s between pages to stay under the rate limit.
- For "just show me a few", prefer `-q per_page=N` and read page 1 instead of
  `--paginate` -- some collections are 20+ pages.

## Rate limits

- 300 requests/minute and 20 requests/second, **per account** (shared across
  every API user on `konghq.aha.io`). Be considerate.
- On 429 the response includes `X-Ratelimit-Limit`, `X-Ratelimit-Remaining`,
  `X-Ratelimit-Reset`. Back off until the reset timestamp.

## Field selection tip

GET responses include nested objects (e.g. a feature's `workflow_status`,
`assigned_to_user`, `release`). When you only need a few values, set
`fields=...` to fetch exactly those -- it is both faster and far easier to read
than the full record. To discover what fields exist, GET one record with
`fields=*` once and inspect the keys.
