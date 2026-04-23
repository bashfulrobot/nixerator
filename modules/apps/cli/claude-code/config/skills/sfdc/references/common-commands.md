# sf CLI Command Reference

Curated reference for the `sf` commands this skill uses. Not exhaustive --
full docs at https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/

All commands accept `--target-org <alias-or-username>` to override the
default org. Omit it to use the default (check with `sf org display`).

All commands accept `--json` for structured output, which is usually easier
to parse than the human-readable default.

## Org commands

### `sf org display`
Show details of the default (or specified) org.

```bash
sf org display
sf org display --json | jq '.result | {alias, username, instanceUrl, apiVersion}'
```

### `sf org list`
List every org the CLI has credentials for. Useful to verify you're
targeting the right one.

```bash
sf org list
```

### `sf org login web`
Authenticate a new org interactively via browser.

```bash
sf org login web --alias prod --instance-url https://login.salesforce.com
sf org login web --alias sandbox --instance-url https://test.salesforce.com
```

## Data commands (read)

### `sf data query`
Run a SOQL query. The most-used command in this skill.

```bash
sf data query --query "SELECT Id, Name FROM Account LIMIT 5"

# JSON output for parsing
sf data query --query "..." --json

# CSV output for reports
sf data query --query "..." --result-format csv

# Bulk API for large result sets (>2000 rows)
sf data query --query "..." --bulk --wait 10

# Query on a non-default org
sf data query --query "..." --target-org prod
```

JSON shape:
```json
{
  "result": {
    "records": [ {...}, {...} ],
    "totalSize": 42,
    "done": true
  }
}
```

Use `jq '.result.records[] | {Id, Name}'` to extract.

### `sf data search`
Run a SOSL full-text search across multiple objects.

```bash
sf data search --query "FIND {Acme*} IN NAME FIELDS RETURNING Account(Id, Name), Contact(Id, Name)"
```

### `sf data get record`
Fetch a single record by Id or by unique field. Great for confirming state.

```bash
sf data get record --sobject Account --record-id 001...
sf data get record --sobject Account --where "Name='Acme Corp'"
```

### `sf data export tree`
Export records (plus related records) as a JSON tree, useful for moving
data between sandboxes. Not usually what you want for reports -- use
`sf data query --result-format csv` instead.

```bash
sf data export tree --query "SELECT Id, Name FROM Account WHERE ..." --output-dir ./out
```

### `sf data export bulk`
Bulk export to CSV. Preferred for large datasets.

```bash
sf data export bulk \
  --query "SELECT Id, Name FROM Account" \
  --output-file accounts.csv \
  --wait 10
```

## Data commands (write -- follow the writes playbook)

### `sf data create record`
Insert a single record.

```bash
sf data create record \
  --sobject Account \
  --values "Name='Acme Corp' Industry=Technology"
```

Values are space-separated `Field=Value` pairs. Quote values with spaces.

### `sf data update record`
Update a single record by Id.

```bash
sf data update record \
  --sobject Account \
  --record-id 001... \
  --values "Website=https://acme.example"
```

### `sf data delete record`
Delete a single record by Id.

```bash
sf data delete record --sobject Account --record-id 001...
```

### `sf data upsert`
Bulk upsert from CSV using an external Id as the match key.

```bash
sf data upsert \
  --sobject Account \
  --file accounts.csv \
  --external-id External_Id__c \
  --wait 10
```

### `sf data import bulk`
Bulk insert from CSV.

```bash
sf data import bulk --sobject Account --file new_accounts.csv --wait 10
```

### `sf data delete bulk`
Bulk delete from a CSV of Ids.

```bash
sf data delete bulk --sobject Account --file ids_to_delete.csv --wait 10
```

Any of the above writes must go through the playbook in
`writes-playbook.md`. No exceptions.

## SObject commands

### `sf sobject describe`
Dump the full schema for an SObject. This is how you discover field API
names, types, picklist values, and whether a field is updateable.

```bash
sf sobject describe --sobject Account --json
```

Useful jq slices:
```bash
# Field list with type and updateable flag
sf sobject describe --sobject Account --json | \
  jq -r '.result.fields[] | [.name, .type, .updateable] | @tsv'

# Just picklist values for a specific field
sf sobject describe --sobject Case --json | \
  jq -r '.result.fields[] | select(.name=="Priority") | .picklistValues[].value'

# Required fields for a create
sf sobject describe --sobject Case --json | \
  jq -r '.result.fields[] | select(.createable and .nillable==false and .defaultedOnCreate==false) | .name'
```

### `sf sobject list`
List every SObject in the org.

```bash
sf sobject list --sobject-type standard
sf sobject list --sobject-type custom
sf sobject list --sobject-type all
```

## API / Apex execution (advanced, rarely needed)

### `sf apex run`
Execute anonymous Apex. Opens the door to arbitrary logic and arbitrary
damage -- treat any Apex that writes as a write operation and run the full
playbook on it.

```bash
sf apex run --file script.apex
echo "System.debug([SELECT COUNT() FROM Account]);" | sf apex run
```

### `sf project generate`
Scaffold a DX project, useful if the task needs metadata retrieval.

## Output parsing patterns

Every `sf` command with `--json` produces:
```json
{
  "status": 0,
  "result": { ... },
  "warnings": []
}
```

`status: 0` means success. Non-zero plus a `message` field on error.

Always check status in scripts:
```bash
out=$(sf data query --query "..." --json)
if [[ $(jq -r '.status' <<<"$out") != "0" ]]; then
  echo "Query failed: $(jq -r '.message' <<<"$out")" >&2
  exit 1
fi
```
