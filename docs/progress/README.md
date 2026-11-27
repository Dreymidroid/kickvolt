# Progress tracking

Working log for the build-out sessions. One file per session, plus one
file per agent run so agent work can be audited after the fact.

| File | What it holds |
|---|---|
| `session-2026-11-27.md` | Lead (orchestrator) log: status assessment, branches, merges, decisions, verification results. |
| `agents/<agent>-<task>.md` | Each agent's own log: what it was asked, what it did, commands run, results, open issues. Agents write and update their own file. |
| `../testing/results-<date>.md` | Device test results in the `E2E-testing.md` §B9 format. |

Conventions:
- Every entry is dated (`YYYY-MM-DD HH:MM`, local time) and names the branch.
- Results are copied as the actual tail of the command output, not paraphrased.
- "Not verified" is stated plainly; nothing is marked done without a command that proves it.
