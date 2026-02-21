# Commands

## Justfile shortcuts

Use these for most workflows:

- `just check` - side-effect-free validation with `nix flake check --show-trace`
- `just test` - dry-run rebuild (`nixos-rebuild dry-build`, no staging)
- `just test-staged` - stage all changes, then dry-run rebuild
- `just build` - dev rebuild of the current host (no staging, add `trace=true` for traces)
- `just build-staged` - stage all changes, then run `build`
- `just dev-build` - stage all changes, then production-style `rebuild`
- `just rebuild` - production rebuild of the current host
- `just rebuild-staged` - stage all changes, then run `rebuild`
- `just upgrade` - update flake inputs and rebuild current host
- `just fmt` - format Nix files via `nix fmt`
- `just lint` / `just health` - statix and deadnix checks across Nix files

## Rebuilds (manual)

```bash
# bash/zsh: rebuild current host
sudo nixos-rebuild switch --flake ".#$(hostname)"
```

```fish
# fish: rebuild current host
set -l host (hostname)
sudo nixos-rebuild switch --flake ".#$host"
```

```bash
# Rebuild specific host
sudo nixos-rebuild switch --flake .#qbert
```


## Flake maintenance

```bash
# Check flake
nix flake check --show-trace

# Update all inputs
nix flake update
```

## Backrest

```bash
# Launch Backrest and open UI (on workstations)
backrest-ui

# Manual mode (all hosts)
backrest

# Stop Backrest when finished
# Press Ctrl+C in the terminal where backrest is running
```
