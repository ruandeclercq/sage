---
name: comment
description: Add intent-focused comments to source code and clarify existing comments in a file.
---

# Comment code

Read the whole target file and preserve its comment style.

For every meaningful code block, add or improve a concise comment describing its
intent, invariant, or non-obvious reason. Do not narrate obvious syntax.

Review every existing comment. Rewrite vague, stale, misleading, or redundant
comments, and remove comments that add no useful intent.

Put one blank line before each comment that introduces a code block. Keep the
change limited to comments, then run relevant checks.
