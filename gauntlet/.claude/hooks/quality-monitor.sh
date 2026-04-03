#!/usr/bin/env bash
set -euo pipefail

# Only run when Gauntlet is explicitly active.
# During development sessions GAUNTLET_ACTIVE is not set
# and this hook is a no-op.
if [[ "${GAUNTLET_ACTIVE:-0}" != "1" ]]; then
  echo '{"action": "allow"}'
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Translation Layer — Argument Quality Monitor
# Mercier & Sperber (2011): acceptance must track evidential strength,
# not presentation. Three bias vectors addressed:
# 1. Selection bias — deterministic (grounds reordering)
# 2. Anchoring bias — model-assisted (framing and warrant restatement)
# 3. Qualifier inflation — model-assisted (confidence language normalisation)

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

if [[ "$TOOL_NAME" != "Task" ]]; then
  echo '{"action": "allow"}'
  exit 0
fi

UNIT_FILE="state/argument_unit.json"

if [[ ! -f "$UNIT_FILE" ]]; then
  echo '{"action": "allow"}'
  exit 0
fi

UNIT=$(cat "$UNIT_FILE")

call_claude() {
  local system_prompt="$1"
  local user_content="$2"
  curl -s https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$(jq -n \
      --arg sp "$system_prompt" \
      --arg uc "$user_content" \
      '{
        model: "claude-haiku-4-5-20251001",
        max_tokens: 512,
        system: $sp,
        messages: [{ role: "user", content: $uc }]
      }'
    )" | jq -r '.content[0].text // empty'
}

# ── 1. SELECTION BIAS — deterministic ────────────────────────────────────────
# Reorder grounds by probative_weight descending.
# Most evidentially strong first. Most vivid or emotionally resonant last.
UNIT=$(echo "$UNIT" | jq '
  if (.grounds | length) > 0
  then .grounds |= sort_by(-.probative_weight)
  else .
  end
')

# ── 2. ANCHORING BIAS — model-assisted ───────────────────────────────────────
# The warrant, grounds descriptions, and open_attack content must not
# lead with the conclusion or frame evidence as if the argument is settled.
# The model rewrites language that encodes the conclusion before evidence
# is evaluated, or that presents the warrant as established fact rather
# than as an assumption to be tested.

WARRANT=$(echo "$UNIT" | jq -r '.warrant // ""')

if [[ -n "$WARRANT" ]]; then
  WARRANT_SYSTEM="You are a linguistic normaliser for an argumentation system. Your task is to restate a warrant so that it is clearly presented as an assumption to be evaluated, not as an established fact. The warrant is the inferential bridge between evidence and conclusion. It must be held open to challenge.

Rules:
- Begin the restatement with 'It is assumed that:' followed by the warrant content
- Remove any language that presents the inference as certain, established, or obvious
- Remove any language that implies the argument is already settled
- Do not change the substance of the inference — only the epistemic framing
- Output only the restatement, no preamble

Example input: 'A normal ECG and young age rule out acute cardiac events'
Example output: 'It is assumed that: a normal ECG combined with young age indicates sufficiently low probability of acute cardiac events to support deprioritisation — this inference requires validation against the relevant clinical standard'"

  REWRITTEN_WARRANT=$(call_claude "$WARRANT_SYSTEM" "$WARRANT")
  if [[ -n "$REWRITTEN_WARRANT" ]]; then
    UNIT=$(echo "$UNIT" | jq --arg w "$REWRITTEN_WARRANT" '.warrant = $w')
  fi
fi

# Rewrite grounds descriptions that anchor toward the conclusion
# before the evidence has been evaluated
GROUNDS_COUNT=$(echo "$UNIT" | jq '.grounds | length')

if [[ "$GROUNDS_COUNT" -gt 0 ]]; then
  GROUNDS_SYSTEM="You are a linguistic normaliser for an argumentation system. Your task is to rewrite evidence descriptions so they present the evidence neutrally, without implying that the argument is settled or that the conclusion follows obviously.

Rules:
- Remove language that states the evidence 'confirms', 'proves', 'establishes', 'rules out', or 'clearly indicates' a conclusion
- Replace with neutral evidential language: 'observed', 'measured', 'recorded', 'documented'
- Do not change the factual content of the evidence
- Do not change the probative_weight
- Return a JSON array of ground objects with the same structure as the input
- Output only the JSON array, no preamble

Example input: [{\"content\": \"ECG is normal, ruling out cardiac involvement\", \"source\": \"patient record\", \"probative_weight\": 0.4}]
Example output: [{\"content\": \"ECG within normal limits\", \"source\": \"patient record\", \"probative_weight\": 0.4}]"

  GROUNDS_INPUT=$(echo "$UNIT" | jq '.grounds')
  REWRITTEN_GROUNDS=$(call_claude "$GROUNDS_SYSTEM" "$GROUNDS_INPUT")

  if [[ -n "$REWRITTEN_GROUNDS" ]]; then
    # Validate the output is parseable JSON before writing
    if echo "$REWRITTEN_GROUNDS" | jq '.' > /dev/null 2>&1; then
      UNIT=$(echo "$UNIT" | jq --argjson g "$REWRITTEN_GROUNDS" '.grounds = $g')
    fi
  fi
fi

# Rewrite open_attacks content to ensure neutral evidential gap statements
# Attacks must not be presented as damning indictments or minor footnotes
if [[ $(echo "$UNIT" | jq '.open_attacks | length') -gt 0 ]]; then
  ATTACKS_SYSTEM="You are a linguistic normaliser for an argumentation system. Your task is to rewrite attack descriptions so they state what evidence is missing or what inference is unvalidated, without evaluating the significance of the gap or implying what the verdict should be.

Rules:
- State what evidence is absent or what question is unanswered
- Do not characterise the gap as 'fatal', 'critical', 'minor', 'trivial', or any severity judgment
- Do not use language that implies the argument fails or succeeds
- Do not use language that implies the conclusion is wrong
- Keep the attack type field unchanged
- Keep the source_agent field unchanged
- Return a JSON array of attack objects with the same structure as the input
- Output only the JSON array, no preamble

Example input: [{\"type\": \"undercutting\", \"content\": \"No troponin has been taken, fatally undermining any claim of low cardiac risk\", \"source_agent\": \"classifier\"}]
Example output: [{\"type\": \"undercutting\", \"content\": \"Troponin measurement absent from grounds — the inference from ECG findings to cardiac risk level has not been validated against the primary biomarker for myocardial injury\", \"source_agent\": \"classifier\"}]"

  ATTACKS_INPUT=$(echo "$UNIT" | jq '.open_attacks')
  REWRITTEN_ATTACKS=$(call_claude "$ATTACKS_SYSTEM" "$ATTACKS_INPUT")

  if [[ -n "$REWRITTEN_ATTACKS" ]]; then
    if echo "$REWRITTEN_ATTACKS" | jq '.' > /dev/null 2>&1; then
      UNIT=$(echo "$UNIT" | jq --argjson a "$REWRITTEN_ATTACKS" '.open_attacks = $a')
    fi
  fi
fi

# ── 3. QUALIFIER INFLATION — model-assisted ───────────────────────────────────
# The qualifier field must accurately reflect the evidential support present.
# But qualifier inflation also appears in the body text of grounds and warrant.
# The model checks whether the expressed confidence in the warrant and grounds
# descriptions is proportionate to the probative weight of the evidence.

MEAN_WEIGHT=$(echo "$UNIT" | jq '
  if (.grounds | length) > 0
  then [.grounds[].probative_weight] | add / length
  else 0.5
  end
')

QUALIFIER=$(echo "$UNIT" | jq -r '.qualifier // "presumably"')
GROUNDS_SUMMARY=$(echo "$UNIT" | jq -r '[.grounds[] | "\(.content) (weight: \(.probative_weight))"] | join("; ")')

QUALIFIER_SYSTEM="You are a linguistic normaliser for an argumentation system. Your task is to assess whether the qualifier accurately reflects the evidential support available, and to return the correct qualifier.

Qualifier scale (weakest to strongest):
- 'possibly': mean probative weight below 0.25
- 'presumably': mean probative weight 0.25–0.55
- 'probably': mean probative weight 0.55–0.75
- 'almost certainly': mean probative weight above 0.75

Rules:
- Output only the correct qualifier word or phrase from the scale above
- Base your assessment on the mean probative weight provided and the grounds summary
- Do not output anything other than the qualifier"

  QUALIFIER_INPUT="Mean probative weight: $MEAN_WEIGHT
Current qualifier: $QUALIFIER
Grounds: $GROUNDS_SUMMARY"

  CORRECTED_QUALIFIER=$(call_claude "$QUALIFIER_SYSTEM" "$QUALIFIER_INPUT")

  if [[ -n "$CORRECTED_QUALIFIER" ]]; then
    # Validate it is one of the expected values
    case "$CORRECTED_QUALIFIER" in
      "possibly"|"presumably"|"probably"|"almost certainly")
        UNIT=$(echo "$UNIT" | jq --arg q "$CORRECTED_QUALIFIER" '.qualifier = $q')
        ;;
    esac
  fi

# ── 4. ACCEPTANCE GAP NORMALISATION ──────────────────────────────────────────
# The acceptance_gap must be a neutral retrieval constraint for the constructor.
# Not a criticism. Not an implication about the verdict.
# The constructor uses this field to query for specific missing evidence.

GAP=$(echo "$UNIT" | jq -r '.acceptance_gap // ""')

if [[ -n "$GAP" ]]; then
  GAP_SYSTEM="You are a linguistic normaliser for an argumentation system. Your task is to restate an acceptance gap as a neutral, specific, actionable retrieval constraint.

The acceptance gap is used by the argument constructor to query for missing evidence. It must specify exactly what evidence to look for, with no evaluative framing.

Rules:
- Begin with 'Required:'
- State specifically what evidence, data, or test result is needed
- State the specific standard or protocol that requires it, if known
- Remove any language suggesting the argument is weak, wrong, or fails
- Remove any implication about what the verdict should be
- Be specific enough that a data retrieval system could use it as a query
- Output only the restatement, no preamble

Example input: 'The argument fails because no troponin has been taken and this is essential for any chest pain assessment'
Example output: 'Required: troponin result at T+0, per NICE NSTEMI rule-out protocol (NG185). A baseline high-sensitivity troponin measurement is the primary biomarker for myocardial injury in this presentation type.'"

  NORMALISED_GAP=$(call_claude "$GAP_SYSTEM" "$GAP")

  if [[ -n "$NORMALISED_GAP" ]]; then
    UNIT=$(echo "$UNIT" | jq --arg g "$NORMALISED_GAP" '.acceptance_gap = $g')
  fi
fi

echo "$UNIT" > "$UNIT_FILE"
echo '{"action": "allow"}'