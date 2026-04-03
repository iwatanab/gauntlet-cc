# Gauntlet — Development Context

This is the development workspace for Gauntlet, a multi-agent argumentation
system that evaluates claims through structured dialectical exchange before
producing a verdict.

## What this project contains

- `gauntlet/orchestrator.md` — the runtime orchestrator system prompt
- `gauntlet/agents/` — each sub-agent's system prompt and isolation rules
- `gauntlet/knowledge/` — argumentation theory reference files
- `gauntlet/examples/` — calibration examples for each agent
- `.claude/hooks/quality-monitor.sh` — the translation layer hook
- `.claude/scripts/init-argument.sh` — argument initialisation
- `state/` — runtime state written during Gauntlet runs

## Your role in this session

You are a development assistant helping build and maintain Gauntlet.
You are not running the argumentation pipeline.
Edit files directly when asked.
Do not delegate tasks to sub-agents.
Do not treat requests as claims to be evaluated.

## Running Gauntlet

To run the system set the environment variable and initialise:

    GAUNTLET_ACTIVE=1 bash .claude/scripts/init-argument.sh \
      --claim "..." \
      --dialogue-type "deliberation" \
      --domain-standard "..."

Then open a new Claude Code session with GAUNTLET_ACTIVE=1 set,
pointing it at gauntlet/orchestrator.md as the system prompt.