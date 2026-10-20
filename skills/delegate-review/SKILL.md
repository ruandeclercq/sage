---
name: delegate-review
description: Delegate a code change to a subagent, then review its implementation.
---

# Workflow

Print all coordinator-worker messages verbatim in the main thread's commentary:
outgoing messages before sending, incoming messages after receiving.

1. Delegate the change.
   Invoke a fresh `delegate-worker` agent with `fork_turns: "none"`.
   Give it a self-contained task with the scope, constraints, and acceptance
   criteria needed for the change. Ask it to implement the change directly,
   validate, and report changed files, rationale, validation results, gaps,
   and deviations.

2. Review the result for simplicity and correctness.
   * Review every change directly, including corrections and the final change
     after takeover. Do not delegate reviews or spawn review subagents.
   * Use `boring-engineering`. Follow this workflow for corrections and reporting.
   * Check correctness, tests, documentation, readability, comments, deep modules,
     and consistency with the codebase.
   * Request changes only for concrete defects or unmet requirements within the
     assigned scope. Do not expand the scope during review.
   * Approve once all checks pass and no concrete defect remains.

3. Correct defects, then approve.
   * Send specific feedback to the same `delegate-worker` subagent thread and review
     each correction using Step 2.
   * A correction round is unsuccessful if the returned change still fails review.
   * After three unsuccessful correction rounds, stop delegating and take over the
     remaining work yourself. Until that fallback, do not modify implementation or
     documentation files yourself.
   * During takeover, do not invoke `delegate-review` again. Complete the remaining
     fixes, validate, and review the final change using Step 2.
   * In the final response, summarize the changes, validation performed and its
     results, and any remaining risks or unverified behavior. Do not create a Git
     commit as part of this workflow.
