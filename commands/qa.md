---
name: qa
description: "Analyze QA telemetry from the last Ralpha session"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/qa-analyze.sh:*)", "Read(.claude/ralpha-qa-findings.md)"]
hide-from-slash-command-tool: "true"
---

# Ralpha QA Analysis

Run the QA analyzer on the latest session telemetry:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/qa-analyze.sh"
```

Now read `.claude/ralpha-qa-findings.md` and present the findings to the user.

For each finding:
1. Explain what was detected and why it matters
2. Show the specific file and suggested fix
3. Assess whether it's a real issue or a false positive. Use these criteria:
   - **stuck_loop**: Likely false positive if the session completed in ≤3 iterations (short sessions resemble loops at small scale)
   - **excessive_iterations**: Likely false positive if the objective was genuinely complex (multi-file refactors, new features) — high iteration counts are relative to scope
   - **verification_never_passes**: Likely false positive if the verify command was added late in the session, so early iterations had nothing to pass
   - **idle_waste**: Likely false positive if teammates went idle immediately after finishing their tasks (brief idle before being reassigned is expected)
   - A finding is almost certainly real if the same pattern repeats across 3+ iterations, or if the session ended without completing the objective

If there are MUST-FIX findings, recommend running a self-improvement cycle:

```
/ralpha-team:solo Address the MUST-FIX findings in .claude/ralpha-qa-findings.md \
  --completion-promise 'ALL FINDINGS ADDRESSED' \
  --verify-command 'bash tests/test-runner.sh' \
  --max-iterations 10
```

QA findings feed back into follow-up sessions: session → log → analyze → fix → session.
