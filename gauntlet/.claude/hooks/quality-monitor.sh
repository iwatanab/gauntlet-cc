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
# ... rest of hook unchanged