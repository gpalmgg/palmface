# Metaplan lessons

Twelve rules for specs that several sessions or agents will build independently. Each one exists because ambiguity between sessions produced outputs that could not be merged.

1. **Interchangeability.** A spec is done when two independent sessions would produce outputs you could swap without noticing. Include a reference output, exact paths, closed vocabularies (enumerate allowed tags and statuses), and explicit boundaries.
2. **One writer per path.** Every output path has exactly one owning session. Parallel tracks write to non-overlapping paths fixed in advance.
3. **Explicit boundaries.** Each session lists "Does NOT create" and "Does NOT modify". Well-meaning extras are the commonest source of conflict.
4. **Self-contained.** A session with no prior conversation must be able to do the work from the spec. Carry the reasoning behind decisions, not just the structure.
5. **Anchors, not adjectives.** "Clean" is not a spec. Visual work gets specific fonts, colours (hex), layout pattern, light or dark, and ideally a reference image.
6. **Merge strategy up front.** Each artifact is declared REPLACE (overwrites), ADD (appends) or CREATE (new, must not already exist).
7. **Acceptance in the spec.** Concrete, runnable checks per deliverable: the normal case, edge cases (empty, malformed), and a scale case.
8. **One source of truth per concern.** When documents conflict, the most specific one wins; say which ranks above which.
9. **Interface contracts.** For each producer: output path, required fields or structure, and who consumes it and what they need. A format change updates every consumer spec.
10. **Attention curation.** More output is not more value. Rank results (high prominent, medium condensed, low collapsed) so review takes minutes.
11. **Append-only outputs.** Sessions never overwrite earlier results; new dated files per run. Git is the safety net.
12. **Match the model to the task.** Say which sessions need a strong model (nuanced judgement, design) and which a fast one (templating, indexing), and why.

## Adding a lesson

When a build exposes a new failure, record: what happened, the root cause, and what the spec should have contained.
