#!/usr/bin/env bash

sudo nix flake update
sudo nixos-rebuild switch --flake .#nixerator

exit 0
