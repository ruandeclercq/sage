---
name: commit
description: Write/edit git commit messages
---

# Commit Skill: 50/72 Rule

Use this skill whenever generating Git commit messages.

## Objective

When user invokes $commit, stage relevant changes and run `git commit`.

* Make the subject specific enough to identify the complete scope of the
  change without relying on the body. Name coordinated concerns when they
  materially affect what the commit does.
* Use the subject as the top-level description.
* For messages with a body, begin it with a high-level summary of the change.
  For bug fixes, describe the observed problem and corrected behavior using
  "Before this change, ..." followed by "After this change, ...". Base both
  statements on the diff and validation.
* Follow the summary with one blank line, then bullets covering the important
  details.
* Describe the intent and outcome of the change.
* Use concrete, standalone wording: name what happens, to what, and when.
* Keep the subject to 50 characters or fewer.
* Keep body lines to 72 characters or fewer.
* Insert exactly one blank line between the subject and the body.
* Do not insert other blank lines within the body beyond the separator between
  the summary and bullets.
* Small non-bug-fix changes may only need a subject. Larger changes may need
  a short body.
* Use sentence case.
* MUST read the staged diff or exact commit diff before writing or
  validating a commit message.

## Commit command

Always create multi-line commit messages using `printf` piped to
`git commit -F -`.

For commits with a body:

* You MUST use the `printf '%s\n' ... | git commit -F -` pattern shown
  below.
* Never use multiple `-m` flags.
* Never embed newline escape sequences such as `\n` in shell strings.
* Never use `git commit -m` for a multi-line commit message.

For subject-only commits, use:

```bash
git commit -m "Commit message title"
```

For commits with a body, use:

```bash
printf '%s\n' \
  'Commit message title' \
  '' \
  'High-level summary of the change.' \
  '' \
  '- First detail' \
  '- Second detail' \
| git commit -F -
```
