#!/usr/bin/env bash
set -euo pipefail

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
  echo "Error: --claim is required"; exit 1
fi

if [[ -z "$DOMAIN_STANDARD" ]]; then
  echo "Error: --domain-standard is required"; exit 1
fi

mkdir -p state

ID="arg-$(date +%Y%m%d-%H%M%S)"

jq -n \
  --arg id "$ID" \
  --arg dialogue_type "$DIALOGUE_TYPE" \
  --arg domain_standard "$DOMAIN_STANDARD" \
  --arg claim "$CLAIM" \
  --argjson termination_limit "$TERMINATION_LIMIT" \
'{
  id: $id,
  cycle: 1,
  dialogue_type: $dialogue_type,
  domain_standard: $domain_standard,
  termination_limit: $termination_limit,
  claim: $claim,
  grounds: [],
  warrant: null,
  backing: null,
  qualifier: "presumably",
  scheme: null,
  critical_questions: [],
  open_attacks: [],
  burden_bearer: null,
  stage_audit: null,
  rule_violations: [],
  acceptance: null,
  acceptance_gap: null,
  attack_graph: null,
  extension: null,
  verdict: null,
  rebuttal_log: []
}' > state/argument_unit.json

echo "Initialised ArgumentUnit: $ID"
echo "Written to state/argument_unit.json"