#!/usr/bin/env python3
"""capture-sync.py: 3-way diff sync between ~/.claude/ and repo config/

For each tracked file the script compares three states:

    H = current content in ~/.claude/<rel>            (home)
    R = current content in config/<rel>               (repo)
    S = sha256 recorded in .capture-state.json[<rel>] (snapshot)

and chooses one of these actions:

    noop      H == R == S                           # nothing to do
    capture   R == S and H != S                     # home was edited locally -> copy H to R
    mirror    H == S and R != S                     # repo was updated -> copy R to H
    import    H exists, R missing, S missing        # new manual install -> seed R from H
    bootstrap R exists, H missing, S missing        # first run on a fresh host -> mirror R to H
    delete    H == S and R missing (S present)      # tracked deletion from repo side -> remove H
    refresh   H == R and S != H                     # both sides identical, refresh snapshot
    conflict  H != R and H != S and R != S          # both sides diverged -> abort, surface

The snapshot file lives at <repo-config>/.capture-state.json and is committed
to git so it travels across hosts. Conflicts are reported on stderr and
collected; the script exits non-zero when any conflict is recorded so the
caller can decide whether to abort the rebuild.

Sections handled:

    skills/<name>/<rel>     multi-file, dir walks union of home+repo
    agents/<name>.md        flat .md files (gsd-* prefix is skipped)
    output-styles/<name>    flat files (no extension constraint)
    CLAUDE.md               single top-level file

settings.json and the plugin JSON files have placeholder substitution and
are out of scope here; the fish wrapper keeps the existing behaviour for
those surfaces.

Usage:
    capture-sync.py \\
        --state-file PATH \\
        --home-root  PATH \\
        --repo-root  PATH \\
        [--section skills|agents|output-styles|claude-md|all] \\
        [--ignore-file PATH] \\
        [--dry-run] \\
        [--bootstrap]

Output is JSON on stdout with the per-file action log.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional


def sha256_file(path: Path) -> Optional[str]:
    if not path.exists() or path.is_dir():
        return None
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def load_state(state_file: Path) -> dict:
    if not state_file.exists():
        return {"version": 1, "files": {}}
    try:
        data = json.loads(state_file.read_text())
    except json.JSONDecodeError as exc:
        # A torn write or hand-edit gone wrong shouldn't brick every host
        # that pulls the snapshot. Warn loudly and fall back to a fresh
        # state: the caller will treat existing files as needing a
        # bootstrap snapshot, which is the same recovery path a fresh
        # checkout would take.
        print(
            f"capture-sync: WARNING state file {state_file} is not valid JSON "
            f"({exc}); treating as missing and rebuilding from current state",
            file=sys.stderr,
        )
        return {"version": 1, "files": {}}
    if "files" not in data:
        data["files"] = {}
    return data


def save_state(state_file: Path, state: dict) -> None:
    # Atomic write so a SIGINT, OOM-kill, or concurrent invocation can't
    # leave a committed-and-tracked .capture-state.json half-written.
    state_file.parent.mkdir(parents=True, exist_ok=True)
    tmp = state_file.with_suffix(state_file.suffix + ".tmp")
    tmp.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n")
    os.replace(tmp, state_file)


def read_ignore(ignore_file: Optional[Path]) -> set[str]:
    out: set[str] = set()
    if ignore_file is None or not ignore_file.exists():
        return out
    for raw in ignore_file.read_text().splitlines():
        line = raw.strip()
        if line and not line.startswith("#"):
            out.add(line)
    return out


@dataclass
class Decision:
    key: str
    action: str
    reason: str
    home_hash: Optional[str] = None
    repo_hash: Optional[str] = None
    snap_hash: Optional[str] = None


def reconcile(
    key: str,
    home_path: Path,
    repo_path: Path,
    snap_hash: Optional[str],
    bootstrap: bool,
) -> Decision:
    H = sha256_file(home_path)
    R = sha256_file(repo_path)
    S = snap_hash

    if H is None and R is None:
        return Decision(key, "noop", "neither side has the file", H, R, S)

    if H is not None and R is None:
        if S is None:
            return Decision(key, "import", "new in home, not in repo or snapshot", H, R, S)
        if H == S:
            return Decision(
                key,
                "delete-home",
                "repo deleted file and home was untouched; removing home",
                H,
                R,
                S,
            )
        return Decision(
            key,
            "conflict",
            "repo deleted the file but home was edited",
            H,
            R,
            S,
        )

    if H is None and R is not None:
        if S is None:
            return Decision(key, "bootstrap", "exists in repo but not in home; mirroring", H, R, S)
        if R == S:
            return Decision(
                key,
                "mirror",
                "home was deleted, repo unchanged; restoring from repo",
                H,
                R,
                S,
            )
        # home deleted AND repo changed: the user's home-side deletion
        # intent might be a delete-from-repo, but repo also moved (probably
        # via a PR), so silently overriding either side is wrong. Surface.
        return Decision(
            key,
            "conflict",
            "home was deleted AND repo was updated since last snapshot",
            H,
            R,
            S,
        )

    # Both H and R exist.
    if H == R:
        if S != H:
            return Decision(key, "refresh", "both sides identical, refreshing snapshot", H, R, S)
        return Decision(key, "noop", "in sync", H, R, S)

    # H != R from here on.
    if S is None:
        if bootstrap:
            return Decision(
                key,
                "conflict",
                "no snapshot exists and home differs from repo; pick a side with capture-resolve",
                H,
                R,
                S,
            )
        return Decision(
            key,
            "conflict",
            "no snapshot exists and home differs from repo; rerun with --bootstrap "
            "after resolving, or use capture-resolve",
            H,
            R,
            S,
        )

    if R == S and H != S:
        return Decision(key, "capture", "home was edited locally; capturing to repo", H, R, S)

    if H == S and R != S:
        return Decision(
            key, "mirror", "repo was updated (PR/merge); mirroring repo to home", H, R, S
        )

    return Decision(
        key,
        "conflict",
        "both home and repo diverged from snapshot",
        H,
        R,
        S,
    )


def apply_decision(
    decision: Decision, home_path: Path, repo_path: Path, dry_run: bool
) -> Optional[str]:
    """Apply the decision to the filesystem; return the new snapshot hash.

    Uses shutil.copy (not copyfile) so the source mode bits are preserved.
    Hard-coding 0o644 would strip the executable bit from tracked helper
    scripts like skills/slack-post/scripts/slack-post.sh and the sfdc-*.sh
    helpers (committed at 100755 in git), breaking both the repo's tracked
    mode and the runtime invocation from ~/.claude.
    """
    action = decision.action

    if action == "noop":
        return decision.snap_hash

    if action == "conflict":
        return decision.snap_hash

    if dry_run:
        if action in ("import", "capture"):
            return decision.home_hash
        if action in ("mirror", "bootstrap"):
            return decision.repo_hash
        if action == "refresh":
            # H == R at decision time; pick either.
            return decision.repo_hash
        if action == "delete-home":
            return None
        return decision.snap_hash

    if action in ("import", "capture"):
        # Belt-and-braces against a TOCTOU swap of the source for a
        # symlink between enumeration and copy: refuse to read through
        # a symlink. _safe_walk already filters at enumeration, this
        # closes the race window.
        if home_path.is_symlink():
            print(
                f"capture-sync: refusing to copy from symlink {home_path}",
                file=sys.stderr,
            )
            return decision.snap_hash
        repo_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(home_path, repo_path, follow_symlinks=False)
        return sha256_file(repo_path)

    if action in ("mirror", "bootstrap"):
        if repo_path.is_symlink():
            print(
                f"capture-sync: refusing to copy from symlink {repo_path}",
                file=sys.stderr,
            )
            return decision.snap_hash
        home_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(repo_path, home_path, follow_symlinks=False)
        return sha256_file(home_path)

    if action == "refresh":
        # Both sides matched at decision time but the snapshot was stale.
        # Re-hash from disk in case anything raced between reconcile and
        # apply; the source we trust here is whichever side we'd otherwise
        # have written, but since H == R either works.
        return sha256_file(repo_path)

    if action == "delete-home":
        try:
            home_path.unlink()
        except FileNotFoundError:
            pass
        return None

    raise AssertionError(f"capture-sync: unknown action {action!r}")


def run_settings(
    home_file: Path,
    repo_file: Path,
    state: dict,
    dry_run: bool,
) -> Decision:
    """Capture-only, snapshot-guarded 3-way for settings.json.

    settings.json is not a plain tracked file: the live ~/.claude copy is a
    DERIVED artifact (activation substitutes the statusline store path and
    injects the plugin overlay, the ask list, and every Nix-owned hook with its
    /nix/store command path). The caller therefore hands us a CANONICALIZED copy
    of home -- those injected bits stripped back out -- as `home_file`, so it is
    byte-comparable to the repo source.

    Unlike the generic sections, home is never written here: activation owns the
    home side and rebuilds it from repo on every switch. So this is capture-only.
    The snapshot (key "settings.json" in the shared state file) is what lets us
    tell "home was live-edited" (capture it) apart from "repo moved via a
    PR/merge while home is stale" (keep repo, do NOT clobber it) -- the exact bug
    the old unconditional home->repo copy caused.

        seed       no snapshot yet          -> record repo as baseline, no write
        noop       Hc == R                  -> in sync
        capture    R == S and Hc != S       -> home live-edited; copy Hc -> repo
        keep-repo  Hc == S and R != S       -> repo moved, home stale; keep repo
        conflict   Hc != R, both != S       -> surface, write nothing
    """
    key = "settings.json"
    files = state.setdefault("files", {})
    H = sha256_file(home_file)
    R = sha256_file(repo_file)
    S = files.get(key)

    if R is None:
        return Decision(key, "noop", "repo settings.json missing; nothing to capture", H, R, S)
    if H is None:
        return Decision(key, "noop", "no home settings.json to capture; keeping repo", H, R, S)
    if S is None:
        decision = Decision(
            key, "seed", "first run; recording repo as baseline without clobbering", H, R, S
        )
    elif H == R:
        decision = Decision(key, "noop", "canonicalized home matches repo", H, R, S)
    elif R == S and H != S:
        decision = Decision(key, "capture", "home was edited live; capturing to repo", H, R, S)
    elif H == S and R != S:
        decision = Decision(
            key, "keep-repo", "repo was updated (PR/merge); home is stale, keeping repo", H, R, S
        )
    else:
        decision = Decision(
            key,
            "conflict",
            "home and repo both diverged from snapshot; reconcile settings.json by hand",
            H,
            R,
            S,
        )

    if dry_run or decision.action == "conflict":
        return decision

    if decision.action == "capture":
        if home_file.is_symlink():
            print(
                f"capture-sync: refusing to capture settings from symlink {home_file}",
                file=sys.stderr,
            )
            return decision
        shutil.copy(home_file, repo_file, follow_symlinks=False)
        files[key] = sha256_file(repo_file)
    elif decision.action in ("seed", "keep-repo"):
        # Advance the snapshot to the repo so the next run is a clean noop once
        # activation has rebuilt home from repo. Never touches the home side.
        files[key] = R
    elif decision.action == "noop" and S != R:
        # Sides matched but the snapshot was stale; refresh it.
        files[key] = R
    return decision


def _safe_walk(root: Path) -> Iterable[Path]:
    """Yield regular files under `root` without crossing any symlink.

    `Path.rglob` follows symlinked sub-directories on CPython, so a
    malicious skill that drops `~/.claude/skills/foo/notes ->
    /etc/something` would silently exfiltrate the target's content into
    the public repo via `shutil.copy`. `os.walk(..., followlinks=False)`
    refuses to descend symlinked directories; combined with the
    per-file `is_symlink()` check, neither symlinked dirs nor symlinked
    files reach the copy path. We also resolve each candidate path and
    confirm it stays under `root` as a belt-and-braces check against
    name-based escapes.
    """
    if not root.exists():
        return
    resolved_root = root.resolve()
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        # In-place mutation of dirnames prunes the walk: drop any entry
        # that is itself a symlink (followlinks=False already prevents
        # descent into one, but this also keeps the listing clean).
        dirnames[:] = [
            d for d in dirnames if not Path(dirpath, d).is_symlink()
        ]
        for name in filenames:
            path = Path(dirpath, name)
            if path.is_symlink():
                continue
            try:
                resolved = path.resolve(strict=True)
            except (OSError, RuntimeError):
                continue
            try:
                resolved.relative_to(resolved_root)
            except ValueError:
                # The resolved target escaped the root somehow (race or
                # link-component we missed); refuse to surface it.
                print(
                    f"capture-sync: skipping {path}; resolved outside root",
                    file=sys.stderr,
                )
                continue
            yield path


def _iter_skill_files(
    home_skills: Path, repo_skills: Path, ignored: set[str]
) -> Iterable[tuple[str, Path, Path]]:
    """Yield (key, home_path, repo_path) tuples for each tracked skill file."""
    names: set[str] = set()
    for root in (home_skills, repo_skills):
        if root.exists():
            for entry in root.iterdir():
                if entry.is_dir() and not entry.is_symlink():
                    names.add(entry.name)

    for name in sorted(names):
        if name in ignored:
            continue

        home_skill = home_skills / name
        repo_skill = repo_skills / name

        # Whole-skill symlink in home means Nix-managed; skip.
        if home_skill.is_symlink():
            continue

        # Skip workspaces and plugin-managed skills (no real SKILL.md, or
        # every leaf is a symlink into /nix/store).
        if home_skill.exists():
            skill_md = home_skill / "SKILL.md"
            if not skill_md.exists() and not (repo_skill / "SKILL.md").exists():
                continue
            real_leaves = list(_safe_walk(home_skill))
            if not real_leaves and not repo_skill.exists():
                continue

        # Union of relative paths from both sides. Each side is walked
        # with _safe_walk so symlinked sub-directories never expose
        # files that resolve outside the skill root.
        rels: set[str] = set()
        for root in (home_skill, repo_skill):
            for f in _safe_walk(root):
                try:
                    rel = f.relative_to(root).as_posix()
                except ValueError:
                    continue
                if ".." in rel.split("/"):
                    continue
                rels.add(rel)

        for rel in sorted(rels):
            key = f"skills/{name}/{rel}"
            yield key, home_skill / rel, repo_skill / rel


def _iter_flat_files(
    home_dir: Path,
    repo_dir: Path,
    section: str,
    ignored: set[str],
    name_filter=lambda n: True,
) -> Iterable[tuple[str, Path, Path]]:
    names: set[str] = set()
    for root in (home_dir, repo_dir):
        if root.exists():
            for entry in root.iterdir():
                if entry.is_file() and not entry.is_symlink():
                    if name_filter(entry.name):
                        names.add(entry.name)

    for name in sorted(names):
        if name in ignored:
            continue
        key = f"{section}/{name}"
        yield key, home_dir / name, repo_dir / name


def _iter_single_file(
    home_path: Path, repo_path: Path, key: str
) -> Iterable[tuple[str, Path, Path]]:
    if home_path.exists() or repo_path.exists():
        yield key, home_path, repo_path


def run_section(
    section: str,
    home_root: Path,
    repo_root: Path,
    state: dict,
    ignored: set[str],
    bootstrap: bool,
    dry_run: bool,
) -> tuple[list[Decision], list[Decision]]:
    files = state.setdefault("files", {})
    decisions: list[Decision] = []
    conflicts: list[Decision] = []

    if section == "skills":
        iterator = _iter_skill_files(home_root / "skills", repo_root / "skills", ignored)
    elif section == "agents":
        iterator = _iter_flat_files(
            home_root / "agents",
            repo_root / "agents",
            "agents",
            ignored,
            name_filter=lambda n: n.endswith(".md") and not n.startswith("gsd-"),
        )
    elif section == "output-styles":
        iterator = _iter_flat_files(
            home_root / "output-styles",
            repo_root / "output-styles",
            "output-styles",
            ignored,
        )
    elif section == "claude-md":
        iterator = _iter_single_file(
            home_root / "CLAUDE.md", repo_root / "CLAUDE.md", "CLAUDE.md"
        )
    else:
        raise SystemExit(f"capture-sync: unknown section {section!r}")

    for key, home_path, repo_path in iterator:
        snap = files.get(key)
        decision = reconcile(key, home_path, repo_path, snap, bootstrap)
        decisions.append(decision)
        if decision.action == "conflict":
            conflicts.append(decision)
            continue
        new_hash = apply_decision(decision, home_path, repo_path, dry_run)
        if not dry_run:
            if new_hash is None:
                files.pop(key, None)
            else:
                files[key] = new_hash

    return decisions, conflicts


def main() -> int:
    ap = argparse.ArgumentParser(
        description=(__doc__ or "").splitlines()[0] if __doc__ else "capture-sync"
    )
    ap.add_argument("--state-file", required=True, type=Path)
    ap.add_argument("--home-root", required=True, type=Path, help="path to ~/.claude")
    ap.add_argument("--repo-root", required=True, type=Path, help="path to repo config dir")
    ap.add_argument(
        "--section",
        default="all",
        choices=["skills", "agents", "output-styles", "claude-md", "all", "none"],
    )
    ap.add_argument("--ignore-file", type=Path, default=None)
    ap.add_argument(
        "--settings-home",
        type=Path,
        default=None,
        help="canonicalized ~/.claude/settings.json (home side) for the capture-only "
        "settings reconcile; requires --settings-repo",
    )
    ap.add_argument(
        "--settings-repo",
        type=Path,
        default=None,
        help="repo config/settings.json (repo side) for the settings reconcile",
    )
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument(
        "--bootstrap",
        action="store_true",
        help="permit snapshot creation from current state when no snapshot exists; "
        "still refuses to silently resolve a home/repo divergence",
    )
    args = ap.parse_args()

    if not args.home_root.exists():
        raise SystemExit(f"capture-sync: --home-root {args.home_root} does not exist")
    if not args.repo_root.exists():
        raise SystemExit(f"capture-sync: --repo-root {args.repo_root} does not exist")

    state = load_state(args.state_file)

    if args.section == "all":
        sections = ["skills", "agents", "output-styles", "claude-md"]
    elif args.section == "none":
        sections = []
    else:
        sections = [args.section]

    all_decisions: list[Decision] = []
    all_conflicts: list[Decision] = []

    for section in sections:
        # Each section gets its own ignore file lookup; the caller can override.
        if args.ignore_file is not None:
            ignore_path = args.ignore_file
        elif section == "skills":
            ignore_path = args.repo_root / "skills" / ".capture-ignore"
        elif section == "agents":
            ignore_path = args.repo_root / "agents" / ".capture-ignore"
        else:
            ignore_path = None

        ignored = read_ignore(ignore_path)

        decisions, conflicts = run_section(
            section,
            args.home_root,
            args.repo_root,
            state,
            ignored,
            bootstrap=args.bootstrap,
            dry_run=args.dry_run,
        )
        all_decisions.extend(decisions)
        all_conflicts.extend(conflicts)

    # settings.json rides the same state file but uses a capture-only reconcile
    # against a caller-supplied canonicalized home copy (see run_settings).
    if args.settings_home is not None and args.settings_repo is not None:
        settings_decision = run_settings(
            args.settings_home,
            args.settings_repo,
            state,
            dry_run=args.dry_run,
        )
        all_decisions.append(settings_decision)
        if settings_decision.action == "conflict":
            all_conflicts.append(settings_decision)

    if not args.dry_run:
        save_state(args.state_file, state)

    summary = {
        "dry_run": args.dry_run,
        "bootstrap": args.bootstrap,
        "sections": sections,
        "actions": [d.__dict__ for d in all_decisions],
        "conflicts": [c.__dict__ for c in all_conflicts],
    }
    print(json.dumps(summary, indent=2, sort_keys=True))

    if all_conflicts:
        # Sentinel-prefixed lines on stderr so the fish wrapper can grep
        # for them without false-positives against the JSON summary on
        # stdout (every JSON line matches a naive "*: *" glob).
        # Sanitize the key and reason against terminal escape sequences
        # in case a hostile filename ever reaches the conflict surface.
        print("", file=sys.stderr)
        print("capture-sync: unresolved conflicts:", file=sys.stderr)
        for c in all_conflicts:
            safe_key = c.key.encode("ascii", "backslashreplace").decode("ascii")
            safe_reason = c.reason.encode("ascii", "backslashreplace").decode("ascii")
            print(
                f"CAPTURE_SYNC_CONFLICT {safe_key}: {safe_reason}",
                file=sys.stderr,
            )
        print("", file=sys.stderr)
        print(
            "Resolve with: just capture-resolve <relpath> --home|--repo",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
