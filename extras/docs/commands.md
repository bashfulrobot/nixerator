# Commands

## Justfile shortcuts

Use these for most workflows:

- `just check` - fast validation with `nix flake check`
- `just test` - dry-run rebuild (`nixos-rebuild dry-build`)
- `just build` - dev rebuild of the current host (add `trace=true` for stack traces)
- `just rebuild` - production rebuild of the current host
- `just fmt` - format Nix files via `nix fmt`
- `just lint` / `just health` - statix and deadnix checks across Nix files

## Rebuilds (manual)

```bash
# Rebuild current host
sudo nixos-rebuild switch --flake .#$(hostname)

# Rebuild specific host
sudo nixos-rebuild switch --flake .#qbert
```

## Flake maintenance

```bash
# Check flake
nix flake check

# Update all inputs
nix flake update
```
