{ pkgs }:

let
  # Apply skillfish-tracked skill updates and report what changed.
  #
  # skillfish (apps.cli.skillfish, pulled in by suites.ai) tracks skills
  # installed from GitHub via `skillfish add`. Unlike the Nix-vendored
  # skills under config/skills/ (managed by claude-capture) these have an
  # upstream source and can drift. This wrapper runs the apply, then prints
  # a one-line summary of what moved and -- when something was updated and a
  # desktop notifier is present -- fires a notify-send popup. Headless hosts
  # (srv: no notify-send) silently skip the popup.
  #
  # Manual-vendor exception: `config/skills/csp-draft/` is an external skill
  # authored outside this repo (Kong AI Cowork, author andrew.euston@konghq.com)
  # and dropped in by hand. It has an upstream, but not a machine-trackable one
  # (no GitHub source, so `skillfish update` below never sees it). To refresh it
  # when a new version ships: get the updated skill folder from the author, then
  # replace `config/skills/csp-draft/` wholesale (keep it unpatched so drops diff
  # cleanly) and rebuild. It deploys to ~/.claude via the rsync in cfg/activation.nix
  # like any other config/skills entry.
  #
  # Guard on skillfish being on PATH so the command is a harmless no-op on
  # hosts where the skillfish module isn't enabled.
  claudeSkillUpdates = pkgs.writeShellApplication {
    name = "claude-skill-updates";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      if ! command -v skillfish >/dev/null 2>&1; then
        exit 0
      fi

      result="$(skillfish update --yes --json 2>/dev/null || echo '{}')"

      # `updated`/`errors` element shapes aren't documented; accept either a
      # bare string or an object with a name/message field.
      mapfile -t updated < <(
        printf '%s' "$result" \
          | jq -r '.updated[]? | if type=="string" then . else (.name // .skill // tostring) end'
      )
      mapfile -t failed < <(
        printf '%s' "$result" \
          | jq -r '.errors[]? | if type=="string" then . else (.message // tostring) end'
      )

      count=''${#updated[@]}
      if [[ "$count" -eq 0 ]]; then
        echo "[skill-updates] skillfish skills up to date."
      else
        names="$(
          IFS=", "
          echo "''${updated[*]}"
        )"
        echo "[skill-updates] updated $count skill(s): $names"
        if command -v notify-send >/dev/null 2>&1; then
          notify-send "Claude skills updated" "$count updated: $names" || true
        fi
      fi

      if [[ ''${#failed[@]} -gt 0 ]]; then
        printf '[skill-updates] error: %s\n' "''${failed[@]}" >&2
      fi
    '';
  };
in
{
  packages = [ claudeSkillUpdates ];
}
