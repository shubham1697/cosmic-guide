#!/usr/bin/env bash
#
# populate.sh — Wrapper to run the CosmicGuide DB populator via Docker.
#
# Usage:
#   ./populate.sh              # populate everything
#   ./populate.sh -h           # horoscopes only
#   ./populate.sh -t           # tarot cards only
#   ./populate.sh -f           # fortune pool only
#   ./populate.sh -c           # compatibility only
#   ./populate.sh -s           # stories only
#   ./populate.sh -S           # seed static data (no LLM)
#   ./populate.sh -F           # force regenerate
#   ./populate.sh -d 2026-04-28  # specific date
#   ./populate.sh --status     # check DB status
#   ./populate.sh -h -f -F     # horoscopes + fortunes, force
#

set -euo pipefail
cd "$(dirname "$0")"

ARGS=()

show_help() {
  cat <<EOF
CosmicGuide DB Populator

Usage: ./populate.sh [flags]

Flags:
  -h    Horoscopes (12 signs)
  -t    Tarot cards (78 cards)
  -f    Fortune pool (12 signs × 5 topics)
  -c    Compatibility (78 pairs)
  -s    Stories (6 categories)
  -S    Seed static data only (no LLM needed)
  -F    Force regenerate even if data exists
  -d    Target date (YYYY-MM-DD), default: today
  --status  Print DB content status and exit
  --help    Show this help

No flags = populate everything.

Examples:
  ./populate.sh                 # all content
  ./populate.sh -h              # horoscopes only
  ./populate.sh -h -f           # horoscopes + fortunes
  ./populate.sh -h -F           # horoscopes, force regenerate
  ./populate.sh -d 2026-04-28   # all content for specific date
  ./populate.sh --status        # check what's in the DB
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)  show_help ;;
    --status) ARGS+=(--status); shift ;;
    -d)      ARGS+=(--date "$2"); shift 2 ;;
    -*)
      # Process each character in combined short flags (e.g. -hfF)
      flags="${1#-}"
      for (( i=0; i<${#flags}; i++ )); do
        flag="${flags:$i:1}"
        case "$flag" in
          h) ARGS+=(--horoscopes) ;;
          t) ARGS+=(--tarot) ;;
          f) ARGS+=(--fortunes) ;;
          c) ARGS+=(--compatibility) ;;
          s) ARGS+=(--stories) ;;
          S) ARGS+=(--seed) ;;
          F) ARGS+=(--force) ;;
          *) echo "Unknown flag: -$flag"; show_help ;;
        esac
      done
      shift
      ;;
    *) echo "Unknown argument: $1"; show_help ;;
  esac
done

echo "Running: docker compose --profile populate run --rm populate ${ARGS[*]:-}"
docker compose --profile populate run --rm populate "${ARGS[@]}"
