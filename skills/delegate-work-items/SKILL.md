---
name: delegate-work-items
description: Split a plan into thin vertical work items, then delegate, review, and commit each item.
---

# Workflow

1. Read the plan and split it into thin vertical work items.
   Preserve the plan's requirements. Each item must be independently
   reviewable and testable, with clear scope and acceptance criteria.
   Order dependencies first. Keep small cohesive tasks intact.

2. For each work item, implement, review, and commit.
   Use `delegate-review` with only that item's scope, constraints, and
   acceptance criteria. Once approved, commit its changes before starting
   the next item.

3. Return the completed implementation.
   Summarize the completed work items, their commits, validation run, and any remaining risk.
