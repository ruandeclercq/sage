---
name: code-implement
description: Surgical code implementation for feature work, bug fixes, refactors, tests, and validation in an existing codebase.
---

Run this process every time:

1. Inspect the context.
   Read relevant files, tests, patterns, and validation paths.
   Completion criterion: the target, affected areas, local conventions, and
   validation path are known.

2. Choose the smallest correct design.
   Reuse existing abstractions, follow local style and language best-practicies+idioms.
   Avoid speculative abstractions and unrelated behavior.
   Completion criterion: the approach satisfies the request with the smallest
   plausible change.

3. Implement the change.
   Keep edits localized. Preserve existing behavior. Add comments to each
   code block explaining intent, constraints, tradeoffs, and non-obvious behavior.
   Completion criterion: the requested behavior is represented and the code is
   internally consistent.

4. Validate the change.
   Run the narrowest relevant tests or checks first, then broaden validation
   when the blast radius justifies it. Prefer existing project commands.
   Completion criterion: validation passed, or inability to validate is known.

5. Report the result.
   Summarize what changed, where, validation run, and remaining risk.
   Completion criterion: the outcome is clear without reading the full diff.
