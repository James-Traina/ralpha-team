---
description: "Analyze QA telemetry from the last Ralpha session"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/qa-analyze.sh:*)", "Read(ralpha-qa-findings.md)"]
hide-from-slash-command-tool: "true"
---

# Ralpha QA Analysis

Run the QA analyzer on the latest session telemetry:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/qa-analyze.sh"
```

Now read `ralpha-qa-findings.md` and present the findings to the user.

For each finding:
1. Explain what was detected and why it matters
2. Show the specific file and suggested fix
3. Assess whether it's a real issue or a false positive given the session context

If there are MUST-FIX findings, recommend running a self-improvement cycle:

```
/ralpha-team:solo Address the MUST-FIX findings in ralpha-qa-findings.md \
  --completion-promise 'ALL FINDINGS ADDRESSED' \
  --verify-command 'bash tests/test-runner.sh' \
  --max-iterations 10
```

This creates the dogfooding flywheel: session → QA log → analyze → fix → session.
