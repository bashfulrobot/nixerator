# upsight database schema reference

Database file: `~/.local/share/upsight/upsight.db` (SQLite). This is the file the
CLI and the app both use; `config.toml`'s `[database].path` is ignored.

Verify anything here against the live DB before relying on it — the schema
evolves. Dump current schema with:
```
sqlite3 ~/.local/share/upsight/upsight.db ".schema <table>"
sqlite3 ~/.local/share/upsight/upsight.db ".tables"
```

## Tables (map)

Core CRM: `accounts`, `contacts`, `account_email_domains`, `account_documents`,
`opportunities`, `cases`, `case_comments`, `case_history`, `win_wires`,
`professional_services`, `reach_scores`, `infrastructure`, `infra_catalog`,
`konnect_orgs`, `konnect_org_teams`.

Meetings & summaries: `meeting_summaries`, `meeting_agendas`,
`account_state_summaries`, `calendar_events`, `interactions`, `event`.

Work tracking: `tasks`, `task_comments`, `adhoc_tasks`, `actions`,
`todoist_task_cache`, `todoist_section_cache`, `todoist_task_defer`.

Integrations / cache: `aha_idea_cache`, `aha_comment_cache`,
`aha_endorsement_cache`, `aha_idea_notes`, `idea_ranks`, `product_updates`,
`product_update_account_status`, `products`, `product_catalog`, `sf_change_log`,
`channels`, `teams`, `team_collaborations`, `external_dashboards`,
`notification`, `meta_flags`, `goose_db_version` (migration version).

## accounts

Keyed by `id`; `account_name` is UNIQUE. Join target for most other tables via
their `account_id`.

Identity: `id`, `account_name`, `customer_segment`, `industry`,
`account_executive`, `about_account`, `salesforce_id`, `todoist_project_id`.

Commercials & health: `arr_value`, `tcv`, `renewal_date`, `health_status`
(default 'Healthy'), `renewal_risk` (default 'Low'), `onboarding_status`,
`calculated_health_score`, plus paired `*_status` / `*_notes` columns
(`consumption_*`, `enterprise_features_*`, `oss_presence_*`,
`critical_use_case_*`, `customer_business_health_*`).

Usage: `api_calls_entitlement`, `services_entitlement`, `gateway_services_count`,
`api_calls_count`, `kong_version`.

Links: `kadmin_url`, `sfdc_url`, `contract_url`, `internal_channel_url`,
`external_channel_url`, `account_plan_url`, `success_plan_url` (+ `*_completed`
flags). Treat URLs as potentially sensitive; don't leak them externally.

## meeting_summaries

One row per imported meeting. Written by `upsight summarize`.

Columns: `id`, `account_id` (FK → accounts, ON DELETE CASCADE), `meeting_name`,
`meeting_date` (TEXT `YYYY-MM-DD`), `transcript`, `context_input`,
`full_summary`, `slack_summary`, `slack_summary_markdown`, `full_summary_slack`,
`status` (default 'pending'; a completed import is `'completed'`, an interrupted
one is stuck `'processing'`), `error_message`, `ai_binary_used`,
`salesforce_event_id`, `recording_url`, `processed_at`, `created_at`,
`updated_at`, and generated column `meeting_name_norm`.

Dedup key — UNIQUE index on `(account_id, meeting_name_norm, meeting_date)`:
```
meeting_name_norm = lower(trim(replace(meeting_name, '-', ' ')))
```
So the same meeting under two differently-worded names on one day makes two rows;
reconcile by `(account_id, meeting_date)` first, then compare names.

## meeting_agendas

`id`, `account_id`, `meeting_title`, `meeting_date`, `slide_markdown`,
`speaker_notes_json`, `ai_enhanced`, `created_at`, `updated_at`.

## account_state_summaries

`id`, `account_id`, `summary_text`, `sources_used`, `ai_binary_used`, `status`,
`error_message`, `created_at`. One AI-generated "state of the account" per row.
