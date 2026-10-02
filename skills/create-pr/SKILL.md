---
name: create-pr
description: Draft a pull request title and body from `origin/main..HEAD`.
---

When invoked, always:

1. Determine commit range as `origin/main..HEAD`.
2. Read all commit subjects in that range (`git log --oneline --no-merges origin/main..HEAD`).
3. Read changed files in that range (`git diff --name-only origin/main..HEAD`) and the full diff (`git diff origin/main..HEAD`). Base behavior claims on the diff and available validation results.
4. Produce a high-level PR summary focused on intent/themes, not per-commit narration.
   - Use concrete, standalone wording: name what happens, to what, and when.
   - For bug fixes, describe the observed problem and corrected behavior using "Before this change, ..." followed by "After this change, ...". Follow the summary with bullets covering the important details.
5. Explicitly include major workstreams (for example: datapath behavior, session manager/state, metrics/observability, harness/reliability, docs/config).
6. Include a “Config changes” section listing newly added/renamed config keys and defaults.
7. Include a short “Validation” section with notable tests/harness coverage changes.
8. If the range is broad, choose a title that reflects the dominant intent across the full range, not just the latest commits.
9. Strictly make output in markdown.
10. Format PR bodies in Bitbucket-safe markdown:
   - use sentence case for headings and bullets
   - prefer headings plus flat bullet lists
   - avoid nested bullet lists
   - use bold prefixes inside bullets instead of sub-lists when grouping items
   - keep blank lines between headings and lists

Do not summarize only recent commits. Summarize the full `origin/main..HEAD` range.
