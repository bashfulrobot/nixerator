#!/usr/bin/env bash
# shellcheck shell=bash
#
# Shared ANSI color constants for extras/scripts/*.bash's info/ok/warn/err
# logging helpers. Each script keeps its own function definitions (some use
# a "[tag]" prefix on every line, some use a symbol like ✓/↑/✗) — that
# presentation choice is intentional per script and is NOT unified here.
# What's shared is the semantic color mapping (blue=info, green=success,
# yellow=warn, red=error, magenta=needs-manual-check), previously copy-pasted
# as raw escape sequences in each script.
#
# Usage:
#   source "${SCRIPT_DIR}/lib/colors.sh"
#   info() { echo -e "${COLOR_BLUE}[mytag]${COLOR_RESET} $*"; }

# shellcheck disable=SC2034 # consumed by scripts that source this file
COLOR_BLUE=$'\033[1;34m'
# shellcheck disable=SC2034
COLOR_GREEN=$'\033[1;32m'
# shellcheck disable=SC2034
COLOR_YELLOW=$'\033[1;33m'
# shellcheck disable=SC2034
COLOR_RED=$'\033[1;31m'
# shellcheck disable=SC2034
COLOR_MAGENTA=$'\033[1;35m'
# shellcheck disable=SC2034
COLOR_RESET=$'\033[0m'
