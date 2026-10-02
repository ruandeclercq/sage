---
name: git-tidy-history
description: Rewrite commits on the current branch into a clean, coherent history.
---

Use thin vertical slices as the commit boundary. Each resulting commit should
deliver one coherent outcome that is independently reviewable and validatable.

Review all commits on the current branch after `origin/main`.

Rewrite the history into a clean review order:

1. Inspect the commits and identify which belong to each vertical slice.
2. Order the slices so they build cleanly on one another.
3. Squash commits within each slice unless separating them materially improves
   reviewability or validation.
4. Rewrite each resulting commit message from the exact final commit diff.
   Do not concatenate original messages. Follow the `commit` skill rules.
   Completion criterion: every message was checked against its final diff and
   passes the commit rules.
5. Verify that each commit is one coherent slice, builds on its parents, and
   has a compliant message.

After rewriting, summarize the resulting commits.
