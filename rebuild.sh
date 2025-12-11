#!/usr/bin/env bash
# temp, may be able to remove
# 
sudo nix flake update
sudo nixos-rebuild switch --flake .#donkeykong

exit 0
