# palmface-deep-plan templates

## plan.md

```markdown
# <Feature>: Plan
Created: YYYY-MM-DD · Spec: <brief or design path>

## Goal
<one sentence>

## Approach
Option A: ... Option B: ... Option C (wildcard): ...
Recommended: <option> because <reasons tied to research.md>

## Files
| Path | Create/Modify | What changes |

## Milestones
### M1: <name> (~30 min)
Changes: ... Code: <real snippet for the tricky part>
Verify: <command and expected result>
### M2: ...

## Dependencies and order
## Does NOT include
## Open questions
```

## build-spec.md

```markdown
# <Feature>: Build spec
Plan: plan.md · Created: YYYY-MM-DD

## Tasks
Each task is a checkbox line, with its acceptance criteria as indented checkbox lines beneath it.

### Group A: <description> (independent, can run in parallel)
- [ ] T1: <title>
  Run as: parallel subagent
  Files: create `path/a`, modify `path/b`
  Do: <4-8 sentences: enough for a fresh session to do it right>
  Depends on: none
  Notes: <constraints, edge cases>
  - [ ] T1.AC1: <the behaviour that must be true>
    - Setup: `<literal command>` (wait for "<ready text>") | none
    - Verify: <action to take> -> <exact expected result>
    - Depth: <edge cases and quality bar: empty input, bad input, limits, errors>
  - [ ] T1.AC2: <next behaviour>
    - Setup: none
    - Verify: <action> -> <result>
    - Depth: <...>

### Group B: <description> (sequential)
- [ ] T2: <title>
  Run as: one subagent, careful review (modifies critical code)
  Files: modify `path/c:45-120`
  Depends on: T1
  - [ ] T2.AC1: <behaviour>
    - Setup: none
    - Verify: <action> -> <result>
    - Depth: <...>

## Verification sequence
1. Build command  2. Test command  3. End-to-end check  4. Manual look

## Cannot be tested automatically
- <thing needing human judgement, and why>
```

Rules: every task carries at least one `T<n>.AC<k>` criterion; every criterion sits under exactly one task; a task with no criterion is either unnecessary (cut it) or reveals a missing criterion (add it). Verify fields are things you do, never things you read. Building ticks a criterion box only after a reviewer verified it, and the task box once all its criteria are ticked; status and retro count the criterion boxes.
