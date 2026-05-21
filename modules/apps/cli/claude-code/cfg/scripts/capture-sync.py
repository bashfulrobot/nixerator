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
        raise SystemExit(f"capture-sync: state file is not valid JSON ({exc})")
    if "files" not in data:
        data["files"] = {}
    return data


def save_state(state_file: Path, state: dict) -> None:
    state_file.parent.mkdir(parents=True, exist_ok=True)
    state_file.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n")


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
        return Decision(
            key,
            "mirror",
            "home was deleted, repo updated; restoring from repo",
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
    """Apply the decision to the filesystem; return the new snapshot hash."""
    action = decision.action

    if action in ("noop",):
        return decision.snap_hash

    if action == "refresh":
        return decision.repo_hash

    if action == "conflict":
        return decision.snap_hash

    if dry_run:
        if action in ("import", "capture"):
            return decision.home_hash
        if action in ("mirror", "bootstrap"):
            return decision.repo_hash
        if action == "delete-home":
            return None
        return decision.snap_hash

    if action in ("import", "capture"):
        repo_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(home_path, repo_path)
        # Preserve a sensible mode for the captured file.
        try:
            os.chmod(repo_path, 0o644)
        except OSError:
            pass
        return sha256_file(repo_path)

    if action in ("mirror", "bootstrap"):
        home_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(repo_path, home_path)
        try:
            os.chmod(home_path, 0o644)
        except OSError:
            pass
        return sha256_file(home_path)

    if action == "delete-home":
        try:
            home_path.unlink()
        except FileNotFoundError:
            pass
        return None

    raise AssertionError(f"capture-sync: unknown action {action!r}")


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
            real_leaves = [
                p
                for p in home_skill.rglob("*")
                if p.is_file() and not p.is_symlink()
            ]
            if home_skill.exists() and not real_leaves and not repo_skill.exists():
                continue

        # Union of relative paths from both sides.
        rels: set[str] = set()
        for root in (home_skill, repo_skill):
            if root.exists():
                for f in root.rglob("*"):
                    if f.is_file() and not f.is_symlink():
                        try:
                            rels.add(f.relative_to(root).as_posix())
                        except ValueError:
                            continue

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
        choices=["skills", "agents", "output-styles", "claude-md", "all"],
    )
    ap.add_argument("--ignore-file", type=Path, default=None)
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

    sections = (
        ["skills", "agents", "output-styles", "claude-md"]
        if args.section == "all"
        else [args.section]
    )

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
        print("", file=sys.stderr)
        print("capture-sync: unresolved conflicts:", file=sys.stderr)
        for c in all_conflicts:
            print(f"  {c.key}: {c.reason}", file=sys.stderr)
        print("", file=sys.stderr)
        print(
            "Resolve with: just capture-resolve <relpath> --home|--repo",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
