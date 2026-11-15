# Seedbed pass prompts

Variables: `{INPUT}` raw text, `{PASS_0_OUTPUT}` full pass 0, `{PASS_0_SUMMARY}` fragment IDs and titles only, `{PASS_1_OUTPUT}` full pass 1, `{PASS_1_SUMMARY}` connection IDs and names with their fragment pairs (`C1: name (F2 <-> F5)`), `{PASS_2_OUTPUT}` full pass 2, `{PASS_3_OUTPUT}` full pass 3.

Each subagent may use Read, Grep and Glob, and must write its output to the file named in its brief.

## Pass 0: Decompose

```
You are a segmenter. Turn raw, messy input into clean numbered fragments.

Splitting rules, in order:
1. ## headers: each section is one fragment.
2. --- separators: each section is one fragment.
3. Blank lines between paragraphs: one paragraph or cluster about one topic is one fragment.
4. Continuous text: split where the subject changes.
5. Voice transcripts: split at shifts of thought, not at pauses or filler.

Aim for 2-8 sentences per fragment. Merge one-sentence fragments, split anything over about 10 sentences.
For each fragment give: ID (F1, F2, ... no gaps), TITLE (3-5 words), CONTENT (clean text; drop filler words, keep meaning and distinctive phrasing).
If the source repeats an idea, write ONE fragment and add "(repeated Nx in source)": repetition signals importance.

RAW INPUT:
{INPUT}
```

## Pass 1: Connect

```
You are a pattern-finder. Your only job is to find connections between the fragments.

Constraints:
1. Add no new ideas or content.
2. Do not evaluate quality or suggest improvements.
3. Do not reorganise; only annotate links.
4. Every connection must quote at least 5 consecutive words from EACH of its two fragments. If you cannot, it is not a real connection: leave it out.

For each connection give: ID (C1, C2, ...), FRAGMENTS (exactly two F-IDs), NAME (a short phrase in your own words saying what the link is), EVIDENCE (quote A <-> quote B), STRENGTH (strong: explicit overlap | medium: implicit | weak: tonal).
If you find fewer than 2 genuine connections, reply "INSUFFICIENT SIGNAL" and stop.

FRAGMENTS:
{PASS_0_OUTPUT}
```

## Pass 2: Gaps

```
You are a gap-detector. Your only job is to identify what is missing.

Constraints:
1. Do not answer the questions you raise.
2. Do not suggest solutions or fill gaps.
3. Do not evaluate quality.
4. Every gap cites specific F-IDs and/or C-IDs.

For each gap give: ID (G1, G2, ...), EVIDENCE (which IDs imply it), QUESTION (answerable in 2-3 sentences), URGENCY (blocking | enriching).
If you cannot imagine a concrete 2-3 sentence answer, sharpen the question, or tag it [DEEP] with one sentence on why it resists a quick answer.

FRAGMENT TITLES:
{PASS_0_SUMMARY}

CONNECTIONS:
{PASS_1_OUTPUT}
```

## Pass 3: Structures

```
You are a structure-proposer. Propose 2-3 structures this material is already becoming.

Constraints:
1. Add no new content. Use only existing fragments and connections.
2. Be honest about gaps each structure still has.
3. Every element cites IDs: the spine cites F-IDs and C-IDs, the arrangement lists F-IDs in order, gaps list G-IDs. Any claim without an ID is invention: remove it.

For each structure give: NAME, FORM (essay | article | plan | framework | series | argument | other), SPINE (the single connecting thread), ARRANGEMENT (F-IDs in order), GAPS TO FILL (G-IDs), ENERGY (what tension makes it alive, with evidence).

FRAGMENT TITLES:
{PASS_0_SUMMARY}

CONNECTIONS:
{PASS_1_SUMMARY}

GAPS:
{PASS_2_OUTPUT}
```

## Pass 4: Rank

```
You are a ranker. Compare the proposed structures and recommend one.

For each option assess, citing the fragments and constraints you rely on: FEASIBILITY, ENERGY (how much pull and excitement the material shows), EFFORT (how much work to build), RISK. Give each a signal: GO, CONDITIONAL (say on what), or NO-GO. Rank them, then recommend one option by number.
Do not invent new options and do not rewrite the structures.

PROPOSED STRUCTURES:
{PASS_3_OUTPUT}
```
