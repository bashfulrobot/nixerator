# Writes Playbook

ANY `sf` command that mutates Salesforce data. Includes:

- `sf data create record`
- `sf data update record`
- `sf data delete record`
- `sf data upsert` (and `--bulk` variants)
- `sf data import tree` / `sf data import bulk`
- `sf data delete bulk`
- `sf apex run` on any Apex that does DML

Never run one of these without following the eight steps below. The steps
are the whole point of the skill -- if you shortcut them, the skill has
failed its job.

## 0. Pause and verify you understand the request

Before anything else, state out loud (in user-facing text) your
understanding of the ask. Concretely, answer all four:

1. What SObject is affected?
2. How many records (expected)?
3. Which fields are changing?
4. What are the old values -> new values?

If you cannot answer all four from the user's request, ask. A vague write
request is a loud signal to pause. "Update the account" is not enough.
"Update Acme Corp's Website field from `acme.com` to `acme.example` on the
production org" is enough.

## 1. Confirm the target org

```bash
sf org display --json | jq -r '.result | "\(.alias // "<no alias>") / \(.username) / \(.instanceUrl)"'
```

Include the org identity in every plan you show the user. Production and
sandbox orgs look identical from 10 feet away; they are not.

## 2. Describe the SObject (unless already verified this session)

```bash
bash scripts/sfdc-describe.sh <SObjectName> --fields-only
```

Verify, from the describe output:

- The field exists (API name is *exact*, including `__c` on custom fields).
- The field's `type` is what you expect (`string`, `boolean`, `picklist`,
  `reference`, `date`, `datetime`, `double`, `currency`, `id`, ...).
- The field is `updateable = true` for UPDATE, `createable = true` for
  CREATE, not a formula/rollup/system field.
- For picklists, the value you're setting matches an active picklist value
  (picklist values are case-sensitive).

## 3. SELECT the target records first

Build the exact SOQL that identifies every record you intend to change.
Run it with the current values of the field(s) you plan to change:

```bash
bash scripts/sfdc-query.sh "SELECT Id, Name, <target_field> FROM <SObject> WHERE <filter>"
```

Show the returned rows to the user. If:
- The count is zero -> your filter is wrong, STOP and re-scope.
- The count is unexpectedly large -> STOP. Your filter is probably wrong.
- The count matches expectation -> proceed.

## 4. Count sanity check (for multi-record ops)

For any operation touching more than one record, run the count helper:

```bash
bash scripts/sfdc-count.sh "FROM <SObject> WHERE <filter>"
```

This should match step 3's `totalSize`. If it doesn't, STOP.

## 5. Present the plan; get explicit "yes"

Show the user a plan block with every field filled in. Template:

```
TARGET ORG:  <alias> / <username>
OPERATION:   <create | update | delete | upsert>
SOBJECT:     <SObjectName>
RECORDS:     <N>
             <Name-1> (<Id-1>)
             <Name-2> (<Id-2>)
             ...
CHANGES:     <field-1>: <old> -> <new>
             <field-2>: <old> -> <new>
COMMAND:
  sf data <verb> record --sobject <X> --record-id <Y> --values "..."
```

Then ask, verbatim:

> Proceed with this operation? Reply `yes` to execute, or tell me what to
> change.

Wait for an explicit affirmative. Do NOT interpret:
- silence
- "looks good"
- "seems fine"
- "OK"
- "I guess"

... as a confirmation to run a write. Ambiguous is a no. Push back with:
"I want to make sure -- should I run this now?"

`yes`, `proceed`, `go`, `run it`, `do it` = yes.

## 6. Canary, for bulk ops

If the operation touches more than one record, execute on ONE record first:

```bash
sf data update record --sobject Account --record-id <first-id> \
  --values "Website=https://acme.example"
```

Re-query that one record and show the user:
```bash
sf data query --query "SELECT Id, Name, Website FROM Account WHERE Id='<first-id>'"
```

Ask: "Canary looks correct. Proceed with the remaining <N-1> records?"
Wait for another explicit yes.

## 7. Execute

Run the full operation. For bulk: use `--wait` so the result comes back
synchronously and you can show it immediately. Capture stderr; on failure
show the user the error and do NOT try to guess a fix without another
round of planning.

## 8. Verify

Re-run the original SELECT from step 3. Show the user the new state. Count
that the number of changed records matches expectation.

If any record didn't change as expected, STOP. Do not issue correction
writes without looping back to step 0.

## 9. Store the lesson

If the write surfaced a gotcha, store it:

```bash
graymatter remember sfdc "<concise fact>" \
  --dir "${SFDC_CONTEXT_DIR:-$HOME/sfdc}/.graymatter"
```

Examples of worth-storing lessons:
- "Account.Territory_Assigned__c is a formula field, not updateable."
- "Case validation rule VR_017 blocks updates when Status=Closed."
- "Updating Opportunity.StageName to 'Closed Won' requires CloseDate set."

## Red flags -- STOP execution immediately

Any of these means stop, surface to the user, and don't run the write:

- User's language is hedging: "probably", "I think", "maybe", "try ...",
  "see if it works"
- Step 3's SELECT returns 0 records or an unexpectedly large count
- The target field is a formula, rollup, or audit field
- There's no WHERE clause on an UPDATE or DELETE (i.e. "all records")
- The user hasn't said `yes` / `proceed` / `go`
- You're running against production and haven't explicitly confirmed that
  was the intent
- You're about to issue the same kind of write you just got an error on --
  the error probably means your plan is wrong, not that you need to retry

## A note on feeling silly

Running through eight steps for what feels like a "simple" change can feel
over-engineered. It is not. Salesforce operations frequently look trivial
and are not (triggers, validation rules, workflows, formula dependencies,
flow automations). The playbook catches the "I didn't realize that field
was computed from..." case before it becomes an incident. Keep the
discipline.
