{
  "kong": {
    "kongKonnectPAT": "{{ op://automation/kong-konnect-pat/lab-pat-2026-06 }}"
  },
  "aha": {
    "apiToken": "{{ op://nixerator/aha/credential }}"
  },
  "forgejo": {
    "apiToken": "{{ op://nixerator/forgejo-api/token }}"
  },
  "syncthing": {
    "gui": {
      "user": "{{ op://nixerator/syncthing-gui/username }}",
      "password": "{{ op://nixerator/syncthing-gui/password }}"
    }
  },
  "restic": {
    "srv": {
      "restic_repository": "{{ op://nixerator/restic-srv/repository }}",
      "restic_password": "{{ op://nixerator/restic-password/password }}",
      "b2_account_id": "{{ op://nixerator/b2-credentials/keyID }}",
      "b2_account_key": "{{ op://nixerator/b2-credentials/applicationKey }}",
      "region": "{{ op://nixerator/restic-srv/region }}"
    },
    "workstation": {
      "restic_repository": "{{ op://nixerator/restic-workstation/repository }}",
      "restic_password": "{{ op://nixerator/restic-password/password }}",
      "b2_account_id": "{{ op://nixerator/b2-credentials/keyID }}",
      "b2_account_key": "{{ op://nixerator/b2-credentials/applicationKey }}",
      "region": "{{ op://nixerator/restic-workstation/region }}"
    }
  },
  "github": {
    "accessToken": "{{ op://nixerator/github-pat/credential }}"
  },
  "tailscale": {
    "caddyAuthKey": "{{ op://nixerator/tailscale-caddy-authkey/credential }}"
  },
  "todoist_token": "{{ op://nixerator/todoist/credential }}",
  "nanoclaw": {
    "claudeToken": "{{ op://nixerator/nanoclaw-claude-token/credential }}",
    "onecliDbPassword": "{{ op://nixerator/nanoclaw-onecli-db-password/3fqxhcsfzyenwg3rdblflsclgi }}",
    "slackBotToken": "{{ op://nixerator/clanky-slack-app/Bot-User-Oauth-Token }}",
    "slackAppToken": "{{ op://nixerator/clanky-slack-app/Default-clanky-App-Token }}"
  },
  "grafana": {
    "dashboardsToken": "{{ op://automation/grafana-cloud-dashboards/token }}"
  },
  "tableau": {
    "server": "{{ op://automation/Tableau-PAT/hostname }}",
    "siteName": "{{ op://automation/Tableau-PAT/Site-Name }}",
    "patName": "{{ op://automation/Tableau-PAT/username }}",
    "patValue": "{{ op://automation/Tableau-PAT/credential }}"
  }
}
