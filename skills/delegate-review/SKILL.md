---
name: delegate-review
description: Delegate a code change to a subagent, then review its implementation.
---

# Workflow

1. Delegate the change.
   Invoke a fresh `delegate-worker` agent with `fork_turns: "none"`.
   Give it a self-contained task with the scope, constraints, and acceptance
   criteria needed for the change. Ask it to implement the change directly,
   validate, and report changed files, rationale, validation results, gaps,
   and deviations. The role instructions prohibit recursive delegation and
   committing. You will review its result.

2. Review the result yourself.
   Check correctness, tests, documentation, and consistency with the codebase.
   Look for duplicated helpers or abstractions. Evaluate deep modules,
   simplicity, human readability, and re-use.

3. Iterate until approved.
   Send specific feedback to the same subagent thread. Do not modify
   implementation or documentation files yourself. Return the approved change,
   validation results, and remaining risks without committing.
