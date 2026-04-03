# Gauntlet

**Better decisions through rigorous argument.**

Gauntlet is a multi-agent argumentation harness built on Claude Code. It subjects any claim — a recommendation, a decision, an assessment — to a structured sequence of theoretical challenges before producing either a justified verdict or an honest record of why justification could not be reached. Both are valid outputs.

Most AI systems optimise for an answer. Gauntlet optimises for a *justified* answer and treats the two as distinct.

---

## Why Gauntlet exists

Formal deduction works when problems are well-formed, premises are fixed, and conclusions follow necessarily. Most consequential decisions are none of these things. Terms are contested. Evidence is incomplete. Multiple considerations must be weighed without a formula for weighting them.

Argumentation theory has spent the better part of a century working out how conclusions get justified under exactly these conditions — how they are challenged, what it takes for a position to hold up under scrutiny, and what an honest system produces when it cannot. Gauntlet translates that body of work into a working AI architecture.

The theoretical foundations are described in the blog series this project accompanies:
- [Part 1 — The Perspectives That Shaped the Field](https://medium.com/@isawatanabe/)
- [Part 2 — Building AI That Argues Well](https://medium.com/@isawatanabe/argumentation-for-ai-part-2-building-ai-that-argues-well-d9ca04c201e6)

---

## How it works

A claim enters the system. It passes through five specialist agents in sequence. An independent translation layer runs between every handoff, stripping language that would cause the receiving agent to accept or reject the argument on presentational rather than evidential grounds. The process cycles until the claim survives, is defeated, or reaches the termination limit — at which point the system produces a documented impasse rather than a forced verdict.

```
Claim
  │
  ▼
Constructor ──── builds the argument unit from the claim
  │                grounds retrieved from data sources if absent
  │                warrant surfaced if implicit
  │
  │ [translation layer]
  │
  ▼
Classifier ───── names the argument type (Walton's scheme taxonomy)
  │                attaches the critical questions that type must survive
  │                unanswered CQs become attack vectors
  │
  │ [translation layer]
  │
  ▼
Exchange Auditor ─ checks whether the exchange is structured fairly
  │                four stages, ten rules (pragma-dialectics)
  │                blocking violations return to Constructor
  │
  │ [translation layer]
  │
  ▼
Acceptance Evaluator ─ tests the argument against the domain standard
  │                    would a reasonable, well-informed expert act on this?
  │                    failure returns a specific retrieval constraint to Constructor
  │
  │ [translation layer]
  │
  ▼
Conflict Resolver ─── computes which arguments survive the attack graph
                       three attack types: rebuttal, undercutting, undermining
                       reinstatement applied where attacks are themselves defeated
                       verdict: survives | defeated | impasse
```

### The Argument Unit

Every agent reads from and writes to a single shared JSON object. No agent communicates with another directly. The orchestrator controls which fields each agent sees, enforcing field-level isolation as a structural guarantee rather than an instruction.

| Group | Fields | Populated by |
|---|---|---|
| Identity | `id`, `cycle`, `dialogue_type`, `domain_standard`, `termination_limit` | Initialisation — fixed, cannot be modified |
| Toulmin structure | `claim`, `grounds[]`, `warrant`, `backing`, `qualifier` | Constructor (Agent 0) |
| Classifier output | `scheme`, `critical_questions[]`, `open_attacks[]`, `burden_bearer` | Classifier (Agent 1) |
| Auditor output | `stage_audit`, `rule_violations[]` | Exchange Auditor (Agent 2) |
| Evaluator output | `acceptance`, `acceptance_gap` | Acceptance Evaluator (Agent 3) |
| Resolver output | `attack_graph`, `extension`, `verdict` | Conflict Resolver (Agent 4) |
| Discourse record | `rebuttal_log[]` | Grows throughout — never cleared |

### The Theoretical Foundations

| Agent | Theoretical basis | The question it answers |
|---|---|---|
| Constructor | Toulmin (1958) | What are the parts of this argument? |
| Classifier | Walton (1989–2020) | What kind of argument is this, and what must it survive? |
| Exchange Auditor | Van Eemeren & Grootendorst (1984–2004) | Is the exchange structured fairly enough to resolve the disagreement? |
| Acceptance Evaluator | Perelman & Olbrechts-Tyteca (1958) | Would a reasonable expert actually act on this? |
| Conflict Resolver | Dung (1995) + ASPIC+ | When arguments compete, which ones survive? |
| Translation Layer | Mercier & Sperber (2011) | Is acceptance tracking evidential strength or presentation? |

### The Contrary Claim Problem

Every claim has a contrary. A system that only evaluates the initial claim produces *plausible* conclusions at best. A *definite* conclusion requires that no valid case exists for the contrary. Gauntlet supports bipolar evaluation — running both the claim and its contrary through the full sequence and comparing outcomes:

| Outcome | Meaning |
|---|---|
| Claim survives, contrary defeated | Definite conclusion — evidence genuinely favours the position |
| Contrary survives, claim defeated | Wrong starting position — contrary should be advanced |
| Both survive | Equipoise — impasse record flags genuine evidential balance |
| Neither survives | Insufficient evidence — system requests more data |

---

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- `jq` — JSON processing in the translation layer hook
- `bc` — arithmetic for qualifier calibration
- `curl` — model API calls in the translation layer
- `ANTHROPIC_API_KEY` set in your environment

```bash
# macOS
brew install jq bc

# Ubuntu / Debian
apt-get install jq bc curl
```

---

## Installation

```bash
git clone https://github.com/your-org/gauntlet.git
cd gauntlet

# Make scripts executable
chmod +x run-gauntlet.sh
chmod +x .claude/hooks/quality-monitor.sh
chmod +x .claude/scripts/init-argument.sh

# Set your API key
export ANTHROPIC_API_KEY="your-key-here"
```

---

## Usage

### Running Gauntlet

```bash
bash run-gauntlet.sh \
  --claim "your claim here" \
  --dialogue-type "deliberation" \
  --domain-standard "describe the reasonable expert for this domain" \
  --termination-limit 3
```

**Parameters**

| Parameter | Required | Description | Values |
|---|---|---|---|
| `--claim` | Yes | The position to be evaluated | Any string |
| `--dialogue-type` | Yes | The type of exchange | `deliberation` \| `inquiry` \| `persuasion` |
| `--domain-standard` | Yes | Definition of the reasonable expert for this domain | Descriptive string |
| `--termination-limit` | No | Maximum cycles before impasse | Integer, default `3` |

**Dialogue types**

- `deliberation` — deciding what to do; burden falls on whoever recommends action
- `inquiry` — establishing what is true; burden falls on whoever advances the claim
- `persuasion` — resolving a conflict of opinion; burden falls on the protagonist

**Domain standard**

Be specific. The acceptance evaluator applies this standard precisely — it determines what evidence a reasonable expert would require before acting on the argument.

```bash
# Too vague
--domain-standard "a medical professional"

# Good
--domain-standard "experienced emergency clinician with knowledge of ACS presentations, familiar with current NICE NSTEMI troponin rule-out protocol NG185"

# Also good for other domains
--domain-standard "senior software architect with distributed systems experience, familiar with CAP theorem and current consensus on microservices boundary design"
--domain-standard "experienced investment analyst applying CFA Institute standards for material non-public information"
```

### Example — triage decision

```bash
bash run-gauntlet.sh \
  --claim "deprioritise this patient" \
  --dialogue-type "deliberation" \
  --domain-standard "experienced emergency clinician with knowledge of ACS presentations, familiar with NICE NSTEMI troponin rule-out protocol NG185" \
  --termination-limit 3
```

### Example — software architecture decision

```bash
bash run-gauntlet.sh \
  --claim "decompose the monolith into microservices" \
  --dialogue-type "deliberation" \
  --domain-standard "senior software architect with distributed systems experience, familiar with current industry consensus on service decomposition trade-offs" \
  --termination-limit 3
```

### Example — policy recommendation

```bash
bash run-gauntlet.sh \
  --claim "implement mandatory two-factor authentication for all users" \
  --dialogue-type "deliberation" \
  --domain-standard "experienced information security professional applying NIST SP 800-63B authentication guidelines" \
  --termination-limit 3
```

### Contrary claim evaluation

```bash
# Run the initial claim
bash run-gauntlet.sh \
  --claim "deprioritise this patient" \
  --dialogue-type "deliberation" \
  --domain-standard "experienced emergency clinician, NICE NSTEMI protocol"

# Save the result
cp state/argument_unit.json state/argument_unit_claim.json

# Run the contrary
bash run-gauntlet.sh \
  --claim "do not deprioritise this patient — continue monitoring" \
  --dialogue-type "deliberation" \
  --domain-standard "experienced emergency clinician, NICE NSTEMI protocol"

# Compare verdicts
echo "Claim:   $(jq -r .verdict state/argument_unit_claim.json)"
echo "Contrary: $(jq -r .verdict state/argument_unit.json)"
```

### Development sessions

Opening Gauntlet's root directory in Claude Code without the `run-gauntlet.sh` wrapper gives you a plain development context. The orchestrator system prompt is not loaded. The translation layer hook is a no-op. You can edit any file freely.

```bash
# Development — just open Claude Code normally
claude

# Runtime — use the wrapper
bash run-gauntlet.sh --claim "..." --dialogue-type "..." --domain-standard "..."
```

---

## Reading the output

### When the argument survives

The full `ArgumentUnit` is returned with the verdict `survives`. Key fields to examine:

```json
{
  "verdict": "survives",
  "claim": "deprioritise this patient",
  "grounds": [
    { "content": "troponin T+3h negative", "probative_weight": 0.9 },
    { "content": "troponin T+0 negative", "probative_weight": 0.7 },
    { "content": "ECG within normal limits", "probative_weight": 0.4 }
  ],
  "warrant": "It is assumed that: two negative troponins under NICE NG185 protocol, combined with normal ECG and atypical pain presentation, indicates sufficiently low acute cardiac risk to support deprioritisation",
  "qualifier": "presumably",
  "extension": "preferred",
  "rebuttal_log": [...]
}
```

The `qualifier` reflects actual evidential support — not the confidence of whoever made the claim. The `rebuttal_log` shows every challenge the argument survived.

### When the argument is defeated

The verdict is `defeated` and the system returns to the Constructor with the `acceptance_gap` as a retrieval constraint. After the termination limit, the `rebuttal_log` is the output — every surviving attack, timestamped and attributed.

```json
{
  "verdict": "impasse",
  "rebuttal_log": [
    {
      "timestamp": "2026-03-29T10:00:00Z",
      "agent": "classifier",
      "attack_type": "undercutting",
      "content": "Troponin measurement absent — the inference from ECG findings to cardiac risk level has not been validated against the primary biomarker for myocardial injury",
      "status": "surviving"
    }
  ]
}
```

A documented impasse is an honest output. It tells the human in the loop exactly what the argument could not survive and why — which is more useful than a confident recommendation that cannot be justified.

---

## Project structure

```
gauntlet/
│
├── CLAUDE.md                          # Development context (not the orchestrator)
├── run-gauntlet.sh                    # Entry point for running the system
│
├── .claude/
│   ├── settings.json                  # Tool restrictions, hook config, agent paths
│   ├── hooks/
│   │   └── quality-monitor.sh         # Translation layer — fires on every agent handoff
│   └── scripts/
│       └── init-argument.sh           # Initialises state/argument_unit.json
│
├── gauntlet/
│   ├── orchestrator.md                # Orchestrator system prompt (loaded at runtime)
│   ├── agents/
│   │   ├── constructor/CLAUDE.md      # Agent 0 — Toulmin
│   │   ├── classifier/CLAUDE.md       # Agent 1 — Walton
│   │   ├── exchange-auditor/CLAUDE.md # Agent 2 — Van Eemeren & Grootendorst
│   │   ├── acceptance-evaluator/CLAUDE.md # Agent 3 — Perelman
│   │   └── conflict-resolver/CLAUDE.md    # Agent 4 — Dung + ASPIC+
│   ├── knowledge/
│   │   ├── walton-schemes.md          # Full scheme taxonomy with critical questions
│   │   ├── pragma-dialectics-rules.md # Ten rules and stage mapping
│   │   └── aspic-attack-types.md      # Rebuttal, undercutting, undermining definitions
│   └── examples/
│       ├── correct-outputs/           # Calibration examples per agent
│       └── incorrect-outputs/         # Known failure modes per agent
│
└── state/
    ├── argument_unit.json             # Live argument state
    └── argument_unit_contrary.json    # Contrary claim state (bipolar evaluation)
```

---

## Design decisions

### Why multi-agent

The isolation between the Constructor and the checker agents is not a preference — it is a theoretical requirement. Mercier and Sperber's argument quality monitor only works if the producing agent cannot monitor its own output. An agent instructed to check its own work will produce well-formatted arguments that still encode the distortion, because bias operates before the formatting instruction runs. Multi-agent is justified by the mechanism, not by convenience.

### Why the translation layer is a hook, not an agent

Hooks are guaranteed to fire. Sub-agents can be skipped. The translation layer must run on every handoff between agents without exception — it is the mechanism that ensures acceptance tracks evidential strength rather than presentation. A `PostToolUse` hook on `Task` calls is the correct implementation.

### Why tool restrictions are in `settings.json`, not in prompts

An agent told not to do something will, under sufficient pressure, do it anyway. Tool restrictions in `settings.json` are enforced by Claude Code regardless of what any prompt says. The Constructor has `WebSearch` because it retrieves grounds. Every checker has `Read` only. The Acceptance Evaluator has `WebSearch` to retrieve current authoritative standards for the domain — a different epistemic purpose from ground retrieval, and equally important. This is structural SOD enforcement, not instructional.

### Why the rebuttal log is never cleared

The rebuttal log is the full record of the discourse — the timestamped, attributed history of every challenge the argument encountered across every cycle. It is the system's primary honesty mechanism. An argument that survived three cycles with seven rebuttal entries is a different kind of conclusion from one that survived in a single cycle with none. The log is the evidence of the work.

### Why impasse is a valid output

A system without a termination limit can cycle indefinitely when the gap identified by the Acceptance Evaluator requires evidence that is genuinely unavailable. The impasse record — a structured log of every surviving attack and the specific evidence that would resolve each — is more useful than a forced verdict. It tells the human in the loop exactly what the argument could not survive and precisely what evidence would change the outcome.

---

## Extending Gauntlet

### Adding a new domain

Gauntlet is domain-agnostic. The `domain_standard` parameter and the Acceptance Evaluator's web search access handle domain-specific criteria at runtime. No code changes are required to apply Gauntlet to a new domain.

### Adding a new argumentation scheme

Add the scheme and its critical questions to `gauntlet/knowledge/walton-schemes.md` following the existing format. The Classifier will pick it up automatically.

### Adding calibration examples

Add new cases to `gauntlet/examples/correct-outputs/` and `gauntlet/examples/incorrect-outputs/`. Reference them in the relevant agent's `CLAUDE.md`. Calibration examples are the primary mechanism for ensuring agents apply theory correctly rather than producing theory-shaped text.

### Running Gauntlet programmatically

`init-argument.sh` produces a `state/argument_unit.json` that can be pre-populated with grounds, warrant, backing, and qualifier before the session begins. If your system already has the evidence, pass it in:

```bash
# Pre-populate with known grounds
jq '.grounds = [
  {"content": "troponin T+0 negative", "source": "lab", "probative_weight": 0.7},
  {"content": "ECG within normal limits", "source": "patient record", "probative_weight": 0.4}
]' state/argument_unit.json > state/argument_unit.json
```

The Constructor will use what is provided and skip retrieval for those fields.

---

## Theoretical background

Gauntlet draws on six traditions in argumentation theory. Each addresses a distinct dimension of the problem of reasoning under uncertainty.

| Theorist | Contribution | What it provides |
|---|---|---|
| **Toulmin** (1958) | The argument unit | Breaks every argument into claim, grounds, warrant, backing, qualifier, and rebuttal — making the implicit explicit |
| **Walton** (1989–2020) | The argument classifier | Names the inference pattern and attaches the specific challenges it is obligated to survive |
| **Van Eemeren & Grootendorst** (1984–2004) | The exchange validator | Checks whether the argumentative exchange is structured fairly enough to actually resolve the disagreement |
| **Perelman & Olbrechts-Tyteca** (1958) | The audience acceptance criteria | Tests whether a reasonable, well-informed person in the relevant domain would actually act on the argument |
| **Dung** (1995) + **ASPIC+** | The conflict resolver | Computes which arguments survive when arguments conflict, using formal attack graph semantics |
| **Mercier & Sperber** (2011) | The argument quality monitor | Ensures argument acceptance tracks evidential strength rather than presentation — applied as an independent translation layer between every agent handoff |

The framework is described in full in the accompanying blog series.

---

## Limitations

**Model reasoning quality.** The Classifier, Exchange Auditor, and Conflict Resolver apply theoretical frameworks through model reasoning. Calibration examples reduce but do not eliminate the risk of schema-shaped output that approximates correct theory application. The Conflict Resolver's extension computation in particular benefits from being checked against the formal algorithm defined in its `CLAUDE.md`.

**Domain standard accuracy.** The Acceptance Evaluator retrieves current authoritative standards via web search. For domains where standards change frequently or where the authoritative source is behind a paywall, the evaluator may approximate rather than apply the standard precisely.

**Contrary claim evaluation.** Bipolar evaluation — running both claim and contrary — produces definite conclusions rather than plausible ones. The current implementation requires two separate runs. A single integrated pass is a planned improvement.

**No persistent memory across sessions.** The `state/argument_unit.json` file persists between runs but is tied to a single argument. Long-running deliberations that accumulate evidence over time require manual state management.

---

## Contributing

Issues and pull requests are welcome. Areas where contributions are most useful:

- Calibration examples for new domains and argument types
- Additional Walton argumentation schemes and critical questions
- Evaluation protocols for assessing agent output quality
- Integration patterns for passing structured data from existing systems into the Constructor

---

## License

MIT

---

## Acknowledgements

This project draws on decades of work in argumentation theory, computational argumentation, and formal argumentation semantics. The primary theoretical sources are cited throughout the agent system prompts and the accompanying blog series.

The implementation uses [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by Anthropic.
