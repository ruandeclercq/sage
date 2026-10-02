# Git hooks

Versioned Git hooks for this repository live here.

Install them manually in any checkout where you want them active.

## Enable the commit-message hook

The optional `commit-msg` hook checks commit-message formatting. It requires
Python 3 and is not installed by `setup.sh`.

For a standard checkout with a `.git/` directory, run from the repository root:

```bash
ln -s ../../git-hooks/commit-msg .git/hooks/commit-msg
```

If a hook already exists, review it before replacing it.
