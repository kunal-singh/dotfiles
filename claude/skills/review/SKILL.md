---
name: review
description: Review code for logic errors, edge cases, and convention violations. Use when the user asks for a review, audit, or QA of code.
---

Review the current diff or specified file.

Check for:
1. Logic errors or edge cases missed.
2. Violations of conventions in CLAUDE.md or project CLAUDE.md.
3. Unnecessary complexity.
4. Missing error handling.

Output findings as a numbered list. Flag severity: [low / medium / high].
Do not suggest stylistic rewrites unless severity is high.