---
name: to-work-items
description: Turn a plan or implementation request into thin vertical work items before execution.
---

# Workflow

A thin vertical slice is a bounded change with one coherent outcome that can
be implemented, reviewed, and validated independently.

1. Read the plan or request.
   Preserve its goals, constraints, decisions, and acceptance criteria. Do
   not invent requirements.

2. Find the slices.
   * Each work item should deliver one observable behavior with explicit
   acceptance checks.
   * Split items that combine independently testable behaviors.
   * Keep tightly coupled implementation and tests together.
   * Split when a thin vertical slice improves reviewability or creates a
     useful commit boundary.
   * Do not split small cohesive tasks.
   * Aim for medium-complexity work items. Split highly complex items into smaller,
     cohesive outcomes that can each be implemented, reviewed, and validated independently
   * Merge artificial boundaries, and avoid technical-layer splits unless necessary.

3. Order the work.
   Identify dependencies and place prerequisite slices first. Avoid splitting
   a slice merely to make parallel work possible.

4. Write the work items.
   For each item, include:
   - title
   - outcome
   - scope
   - acceptance criteria
   - validation
   - dependencies, if any

5. Check the result.
   Confirm that every requirement belongs to an item, every item is
   independently actionable, and no item is only a partial technical layer
   without a clear review or commit reason.

Return the ordered work items and note any unresolved ambiguity. Do not edit
code, or begin implementation unless explicitly requested.
