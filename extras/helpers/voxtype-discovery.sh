#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
OUT="${1:-$SCRIPT_DIR/voxtype-discovery-$(hostname)-$(date +%Y%m%d-%H%M%S).txt}"
REPO_DIR="${2:-$HOME/git/nixerator}"
NIX_CACHE="${NIX_CACHE:-/tmp/nix-cache}"

mkdir -p "$(dirname "$OUT")" "$NIX_CACHE"
: >"$OUT"

has() { command -v "$1" >/dev/null 2>&1; }

section() {
  printf "\n### %s ###\n" "$1" | tee -a "$OUT"
}

run() {
  printf "\n$ %s\n" "$*" | tee -a "$OUT"
  bash -lc "$*" >>"$OUT" 2>&1 || {
    code=$?
    printf "[exit=%s]\n" "$code" | tee -a "$OUT"
  }
}

section "Host"
run "date -Is"
run "uname -a"
has hostnamectl && run "hostnamectl"

section "GPU + drivers"
if has lspci; then
  if has rg; then
    run "lspci -nnk | rg -i -A3 'vga|3d|display'"
  else
    run "lspci -nnk | grep -EiA3 'vga|3d|display'"
  fi
elif has nix; then
  if has rg; then
    run "XDG_CACHE_HOME='$NIX_CACHE' nix shell nixpkgs#pciutils -c bash -lc \"lspci -nnk | rg -i -A3 'vga|3d|display'\""
  else
    run "XDG_CACHE_HOME='$NIX_CACHE' nix shell nixpkgs#pciutils -c bash -lc \"lspci -nnk | grep -EiA3 'vga|3d|display'\""
  fi
else
  run "echo 'lspci missing and nix unavailable'"
fi
run "ls -l /dev/dri || true"
run "lsmod | grep -E 'i915|amdgpu|nouveau|nvidia' || true"

section "Graphics runtime"
if has glxinfo; then
  run "glxinfo -B"
else
  run "echo 'glxinfo missing'"
fi

if has vulkaninfo; then
  run "vulkaninfo --summary"
elif has nix; then
  run "XDG_CACHE_HOME='$NIX_CACHE' nix shell nixpkgs#vulkan-tools -c vulkaninfo --summary"
else
  run "echo 'vulkaninfo and nix missing'"
fi

section "Optional compute stacks"
has nvidia-smi && run "nvidia-smi" || run "echo 'nvidia-smi missing (ok if not NVIDIA)'"
has rocminfo && run "rocminfo | head -n 80" || run "echo 'rocminfo missing (ok if not AMD ROCm)'"
has clinfo && run "clinfo | head -n 120" || run "echo 'clinfo missing'"

section "Nix voxtype context"
if [ -d "$REPO_DIR/.git" ] && has nix; then
  run "cd '$REPO_DIR' && XDG_CACHE_HOME='$NIX_CACHE' nix eval --impure --json --expr 'let f = builtins.getFlake (toString ./.); in builtins.attrNames f.inputs.hyprflake.inputs.voxtype.packages.x86_64-linux'"
  run "cd '$REPO_DIR' && XDG_CACHE_HOME='$NIX_CACHE' nix eval --impure .#nixosConfigurations.donkeykong.config.hyprflake.desktop.voxtype.threads"
  run "cd '$REPO_DIR' && XDG_CACHE_HOME='$NIX_CACHE' nix eval --impure --raw .#nixosConfigurations.donkeykong.config.hyprflake.desktop.voxtype.package.name"
else
  run "echo 'Repo not found at $REPO_DIR or nix missing; skipping flake evals'"
fi

echo
echo "Wrote: $OUT"
echo "Paste that file back here."
