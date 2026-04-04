#!/usr/bin/env bash
# Convenience wrapper — passes arguments to the Gauntlet agent.
# The agent handles initialisation and the full pipeline.
#
# Usage:
#   bash run-gauntlet.sh \
#     --claim "..." \
#     --dialogue-type deliberation \
#     --domain-standard "..." \
#     [--termination-limit 3]

CLAIM=""
DIALOGUE_TYPE="deliberation"
DOMAIN_STANDARD=""
TERMINATION_LIMIT=3

while [[ $# -gt 0 ]]; do
  case $1 in
    --claim)              CLAIM="$2";              shift 2;;
    --dialogue-type)      DIALOGUE_TYPE="$2";      shift 2;;
    --domain-standard)    DOMAIN_STANDARD="$2";    shift 2;;
    --termination-limit)  TERMINATION_LIMIT="$2";  shift 2;;
    *) echo "Unknown argument: $1"; exit 1;;
  esac
done

if [[ -z "$CLAIM" ]]; then
  echo "Error: --claim is required"
  exit 1
fi

if [[ -z "$DOMAIN_STANDARD" ]]; then
  echo "Error: --domain-standard is required"
  exit 1
fi

GAUNTLET_ACTIVE=1 claude --print \
  "Run the gauntlet agent with the following parameters:
  claim: $CLAIM
  dialogue_type: $DIALOGUE_TYPE
  domain_standard: $DOMAIN_STANDARD
  termination_limit: $TERMINATION_LIMIT"
