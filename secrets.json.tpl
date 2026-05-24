{
  "kong": {
    "kongKonnectPAT": "{{ op://Personal/nixerator-secrets/kong_kongKonnectPAT }}"
  },
  "syncthing": {
    "gui": {
      "user": "{{ op://Personal/nixerator-secrets/syncthing_gui_user }}",
      "password": "{{ op://Personal/nixerator-secrets/syncthing_gui_password }}"
    }
  },
  "qbert": {
    "tailscale_ip": "{{ op://Personal/nixerator-secrets/qbert_tailscale_ip }}",
    "syncthing_id": "{{ op://Personal/nixerator-secrets/qbert_syncthing_id }}"
  },
  "donkey-kong": {
    "tailscale_ip": "{{ op://Personal/nixerator-secrets/donkey_kong_tailscale_ip }}",
    "syncthing_id": "{{ op://Personal/nixerator-secrets/donkey_kong_syncthing_id }}"
  },
  "restic": {
    "srv": {
      "restic_repository": "{{ op://Personal/nixerator-secrets/restic_srv_restic_repository }}",
      "restic_password": "{{ op://Personal/nixerator-secrets/restic_srv_restic_password }}",
      "b2_account_id": "{{ op://Personal/nixerator-secrets/restic_srv_b2_account_id }}",
      "b2_account_key": "{{ op://Personal/nixerator-secrets/restic_srv_b2_account_key }}",
      "region": "{{ op://Personal/nixerator-secrets/restic_srv_region }}"
    },
    "workstation": {
      "restic_repository": "{{ op://Personal/nixerator-secrets/restic_workstation_restic_repository }}",
      "restic_password": "{{ op://Personal/nixerator-secrets/restic_workstation_restic_password }}",
      "b2_account_id": "{{ op://Personal/nixerator-secrets/restic_workstation_b2_account_id }}",
      "b2_account_key": "{{ op://Personal/nixerator-secrets/restic_workstation_b2_account_key }}",
      "region": "{{ op://Personal/nixerator-secrets/restic_workstation_region }}"
    }
  },
  "plakar": {
    "qbert": {
      "repository": "{{ op://Personal/nixerator-secrets/plakar_qbert_repository }}",
      "passphrase": "{{ op://Personal/nixerator-secrets/plakar_qbert_passphrase }}",
      "b2_account_id": "{{ op://Personal/nixerator-secrets/plakar_qbert_b2_account_id }}",
      "b2_account_key": "{{ op://Personal/nixerator-secrets/plakar_qbert_b2_account_key }}"
    }
  },
  "context7": {
    "apiKey": "{{ op://Personal/nixerator-secrets/context7_apiKey }}"
  },
  "zai": {
    "apiKey": "{{ op://Personal/nixerator-secrets/zai_apiKey }}"
  },
  "github": {
    "accessToken": "{{ op://Personal/nixerator-secrets/github_accessToken }}"
  },
  "clay": {
    "pin": "{{ op://Personal/nixerator-secrets/clay_pin }}"
  },
  "claudito": {
    "username": "{{ op://Personal/nixerator-secrets/claudito_username }}",
    "password": "{{ op://Personal/nixerator-secrets/claudito_password }}"
  },
  "srv": {
    "tailscale_ip": "{{ op://Personal/nixerator-secrets/srv_tailscale_ip }}"
  },
  "gemini": {
    "apiKey": "{{ op://Personal/nixerator-secrets/gemini_apiKey }}"
  },
  "tailscale": {
    "caddyAuthKey": "{{ op://Personal/nixerator-secrets/tailscale_caddyAuthKey }}"
  },
  "snyk": {
    "token": "{{ op://Personal/nixerator-secrets/snyk_token }}"
  },
  "todoist_token": "{{ op://Personal/nixerator-secrets/todoist_token }}"
}
