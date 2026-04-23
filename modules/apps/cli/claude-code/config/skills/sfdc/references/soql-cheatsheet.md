# SOQL Cheatsheet

Reference for writing correct SOQL queries against Salesforce. Read this
before writing a non-trivial query -- small mistakes here can return the
wrong data silently.

## Basic shape

```sql
SELECT <fields>
FROM <SObject>
WHERE <filter>
GROUP BY <fields>
HAVING <aggregate filter>
ORDER BY <fields> [ASC|DESC] [NULLS FIRST|NULLS LAST]
LIMIT <n>
OFFSET <n>
```

- No `SELECT *`. List fields explicitly.
- Field and SObject names are case-insensitive. String literal *values* are
  case-sensitive (use `LIKE` for fuzzy match, there is no `ILIKE`).
- Max `LIMIT` is 2000 for standard queries, 50000 for bulk. Use
  `--bulk` in the query script for large result sets.
- `OFFSET` is limited to 2000 total. For deep pagination use a keyset
  (e.g., `WHERE CreatedDate > :last_seen`).

## WHERE operators

- `=`, `!=`, `<>`, `<`, `>`, `<=`, `>=`
- `LIKE` with `%` and `_` wildcards (case-sensitive in most orgs):
  `WHERE Name LIKE '%Acme%'`
- `IN (...)`, `NOT IN (...)`:
  `WHERE Industry IN ('Technology', 'Finance')`
- `INCLUDES (...)`, `EXCLUDES (...)` -- multi-select picklists ONLY:
  `WHERE Products__c INCLUDES ('Gateway;Mesh')` (semicolons within a single
  string mean "AND"; separate strings mean "OR")
- `AND`, `OR`, `NOT`, parentheses for grouping
- `IS NULL`, `IS NOT NULL`

## Date literals (no quotes)

These are the killer feature of SOQL. Prefer them over date math.

| Literal | Meaning |
|---|---|
| `TODAY` | Midnight today -> midnight tomorrow |
| `YESTERDAY` | Midnight yesterday -> midnight today |
| `TOMORROW` | Midnight tomorrow -> midnight day-after |
| `LAST_WEEK` / `THIS_WEEK` / `NEXT_WEEK` | Calendar week |
| `LAST_MONTH` / `THIS_MONTH` / `NEXT_MONTH` | Calendar month |
| `LAST_QUARTER` / `THIS_QUARTER` / `NEXT_QUARTER` | Calendar quarter |
| `LAST_YEAR` / `THIS_YEAR` / `NEXT_YEAR` | Calendar year |
| `LAST_FISCAL_QUARTER` / `THIS_FISCAL_QUARTER` / etc. | Uses org fiscal calendar |
| `LAST_N_DAYS:n` | The past n days *including today* |
| `NEXT_N_DAYS:n` | The next n days starting today |
| `N_DAYS_AGO:n` | Exactly n days ago (a single day) |
| `LAST_N_WEEKS:n`, `LAST_N_MONTHS:n`, `LAST_N_QUARTERS:n`, `LAST_N_YEARS:n`, `LAST_N_FISCAL_*:n` | As named |

Examples:
```sql
-- Opportunities closed this quarter
WHERE CloseDate = THIS_QUARTER AND IsClosed = TRUE

-- Cases opened in the last 30 days
WHERE CreatedDate = LAST_N_DAYS:30

-- Activity before the start of last month
WHERE ActivityDate < LAST_MONTH
```

For specific dates, use ISO-8601 without quotes:
```sql
WHERE CreatedDate >= 2026-01-01T00:00:00Z
```

## Aggregate functions

- `COUNT()` -- count rows
- `COUNT(fieldName)` -- count rows where field is non-null
- `COUNT_DISTINCT(fieldName)`
- `SUM(fieldName)`, `AVG(fieldName)`, `MIN(fieldName)`, `MAX(fieldName)`
- Alias with `aliasName`:
  `SELECT Industry, COUNT(Id) accts FROM Account GROUP BY Industry`
- Filter aggregates with `HAVING`, not `WHERE`

```sql
SELECT StageName, COUNT(Id) cnt, SUM(Amount) total
FROM Opportunity
WHERE CloseDate = THIS_YEAR
GROUP BY StageName
HAVING COUNT(Id) > 5
ORDER BY total DESC
```

## Relationship queries

SOQL traverses relationships in two directions:

### Parent -> child (subquery)
```sql
SELECT Name, (SELECT Id, Subject, Status FROM Cases WHERE IsClosed = FALSE)
FROM Account
WHERE Id = '001...'
```

The inner relationship name is the *child relationship name*, usually the
pluralized object name. For custom objects it's `Objects__r` (note: `__r`,
not `__c`).

### Child -> parent (dot notation)
```sql
SELECT Id, Subject, Account.Name, Account.Industry, Owner.Email
FROM Case
WHERE Account.Industry = 'Technology'
```

You can go 5 relationships deep:
`Case.Account.Parent.Parent.Owner.Name` is valid if the hierarchy exists.

## Toolbox for common shapes

### Top N by a sum
```sql
SELECT AccountId, SUM(Amount) total
FROM Opportunity
WHERE IsClosed = TRUE AND CloseDate = THIS_YEAR
GROUP BY AccountId
ORDER BY SUM(Amount) DESC
LIMIT 10
```

### Find duplicates on a field
```sql
SELECT Email, COUNT(Id)
FROM Contact
WHERE Email != NULL
GROUP BY Email
HAVING COUNT(Id) > 1
```

### Records with no children
```sql
SELECT Id, Name
FROM Account
WHERE Id NOT IN (SELECT AccountId FROM Opportunity)
```

### Recently modified
```sql
SELECT Id, Name, LastModifiedDate
FROM Account
WHERE LastModifiedDate = LAST_N_DAYS:7
ORDER BY LastModifiedDate DESC
```

## Common gotchas

1. **String values are case-sensitive** on `=`. `WHERE Industry = 'technology'`
   returns nothing if the picklist value is `'Technology'`. Describe the
   picklist if unsure, or use `LIKE 'Technology'` (still case-sensitive in
   most orgs -- confirm with a test query).
2. **`SELECT *` doesn't exist.** Always list fields. If you need all fields,
   describe the SObject first and build the list.
3. **`LIKE` is case-sensitive** in most orgs. There's no `ILIKE`. For
   case-insensitive search consider SOSL (`sf data search`).
4. **Formula and rollup fields in WHERE are slow** and can hit governor
   limits on large objects. Prefer stored fields when possible.
5. **Audit fields (`CreatedDate`, `LastModifiedDate`, `SystemModstamp`) are
   read-only.** Don't try to UPDATE them.
6. **Null vs. empty string.** Text fields with no value are `NULL`, not
   `''`. Use `IS NULL`, not `= ''`.
7. **Multi-select picklists use `;` as separator.** For `INCLUDES`, combine
   AND with `;` inside one string, OR with separate strings:
   `WHERE Products__c INCLUDES ('A;B', 'C')` means (A AND B) OR C.
8. **IDs are 15 or 18 chars.** The 18-char form is case-safe; 15-char is
   case-sensitive. SOQL accepts both.
9. **Custom object names end in `__c`.** Child relationship names in
   subqueries end in `__r`. Don't confuse them.
10. **Limit of 100 fields per query** for `SELECT`. Big describes produce
    long lists -- prune to what you actually need.
11. **`SECURITY_ENFORCED` vs. `USER_MODE`.** Use `WITH USER_MODE` (newer)
    or `WITH SECURITY_ENFORCED` to respect field-level and object-level
    security in queries run as an admin.

## SOSL (full-text search) -- when SOQL's LIKE isn't enough

SOSL searches across multiple objects at once and is case-insensitive:

```
FIND {Acme*} IN NAME FIELDS
RETURNING Account(Id, Name), Contact(Id, Name, Email)
```

Run via `sf data search --query "..."`. Good for ambiguous "find anything
matching this term" cases.

## Quoting in bash

When passing SOQL to `sf data query`, wrap the whole query in double quotes
(so bash doesn't eat the `*`, `$`, etc.) and use single quotes for SOQL
string literals:

```bash
sf data query --query "SELECT Id FROM Account WHERE Name LIKE '%Acme%'"
```

If the query itself has double quotes, escape them or use a heredoc:

```bash
sf data query --query "$(cat <<'EOF'
SELECT Id, Name FROM Account WHERE Name = 'O''Brien'
EOF
)"
```

Note the doubled `''` to escape a single quote inside a SOQL string.
