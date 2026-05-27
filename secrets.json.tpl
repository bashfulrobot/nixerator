{
  "kong": {
    "kongKonnectPAT": "{{ op://nixerator/kong-konnect-pat/credential }}"
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
  "plakar": {
    "qbert": {
      "repository": "{{ op://nixerator/plakar-qbert/repository }}",
      "passphrase": "{{ op://nixerator/plakar-qbert/passphrase }}",
      "b2_account_id": "{{ op://nixerator/b2-credentials/keyID }}",
      "b2_account_key": "{{ op://nixerator/b2-credentials/applicationKey }}"
    }
  },
  "context7": {
    "apiKey": "{{ op://nixerator/context7/credential }}"
  },
  "zai": {
    "apiKey": "{{ op://nixerator/zai/credential }}"
  },
  "github": {
    "accessToken": "{{ op://nixerator/github-pat/credential }}"
  },
  "gemini": {
    "apiKey": "{{ op://nixerator/gemini/credential }}"
  },
  "tailscale": {
    "caddyAuthKey": "{{ op://nixerator/tailscale-caddy-authkey/credential }}"
  },
  "snyk": {
    "token": "{{ op://nixerator/snyk/credential }}"
  },
  "todoist_token": "{{ op://nixerator/todoist/credential }}"
}
