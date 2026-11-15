---
name: palmface-premortem
description: Run a premortem on a plan, launch, product, hire, strategy or decision. Assume it already failed six months from now, list every genuine reason it died, send one parallel subagent to write each failure's story, assumption and early-warning signs, then synthesise the most likely failure, the most dangerous failure, the hidden assumption and a concrete revised plan. Writes docs/plans/<slug>/premortem.md. Use when being wrong is costly and the course can still change. Triggers on "/palmface-premortem", "premortem this", "what could kill this", "poke holes in this", "what am I missing", "find the blind spots".
argument-hint: "[plan path, slug, or a description of the thing]"
---

# Premortem

A postmortem explains a failure after it happens. A premortem pretends it already happened and works backwards. "Is this a good plan?" invites agreeable answers; "this died, explain how" invites specific, honest ones. Your default is optimism, so the frame is the mechanism: state it explicitly and hold it.

## Good and bad targets

Good: something you are about to build, launch, price, hire for, pivot, or sign, where being wrong is expensive and you can still change course. Bad: a vague idea with no plan yet (help plan it first), a question with one right answer, a request for feedback on a draft, a decision already made and irreversible.

## 1. Context (minimum bar)

Scan before asking: the conversation, any file the user referenced, `docs/plans/<slug>/` (brief, plan), the project's CLAUDE.md. You need three things:

1. **What is it?** Describable back in one sentence.
2. **Who is it for or affected by it?** Audience, customer, team.
3. **What does success look like?** Failure is the inverse of success.

If all three are known, proceed. If not, ask for the most important gap with `AskUserQuestion` (one question; infer rather than ask when you can), then re-check. Do not interrogate; a premortem on thin context yields generic failures.

On autopilot (the user switched it on for this folder with `/palmface-autopilot`, or `PALMFACE_AUTOPILOT=on`), follow `~/.claude/palmface/references/autopilot.md`: do not ask, state the assumptions you made for the three items, log them to `.autopilot/decisions.md`, queue what must wait in `.autopilot/queue.md`, hold sends in `OUTBOX.md`.

## 2. Set the frame

Say it plainly: "Premise: it is six months from now. <the thing> has failed. It is done. We are working out what killed it."

## 3. Raw failure list

In one pass, generate every genuine reason it died. No fixed categories. Each reason is one or two sentences, specific to this plan, grounded in details the user gave, and a real threat (not a trivia item or a one-in-a-thousand edge). The count is whatever is real: four or nine, never padded.

## 4. Deep dives in parallel

Spawn one general-purpose subagent per failure reason, ALL in one message so they run in parallel and cannot influence one another. Brief:

```
You are an investigator in a premortem. You have one failure reason to analyse in depth.

The plan: --- {what it is, who it is for, what success looks like, relevant project context} ---

FRAME: It is six months from now. This plan has failed.
YOUR FAILURE REASON: {reason}

Write how it actually played out, specific and real like a case study, using details from the plan. Output:
1. THE FAILURE STORY: two or three paragraphs naming the moments things went wrong and why.
2. THE UNDERLYING ASSUMPTION: the one thing taken for granted that made this possible, in one sentence.
3. EARLY WARNING SIGNS: one or two observable signals (things that can be seen or measured, not feelings) showing this failure is starting.
Under 300 words. Direct. No hedging, no sugarcoating.
```

## 5. Synthesis

Read every deep dive and write:

1. **Most likely failure**: which is most probable, and why. Where to look first.
2. **Most dangerous failure**: the one that does the most damage even if less likely. Worth insuring against.
3. **Hidden assumption**: the biggest unexamined assumption across all of them. Often the real payoff.
4. **Revised plan**: concrete changes, each mapped to a specific failure. Not "consider your pricing" but "test pricing at X with 20 people before committing publicly". Each should be doable this week.
5. **Pre-launch checklist**: three to five things to verify or put in place, each preventing or detecting a named failure.

## 6. Output

Write `docs/plans/<slug>/premortem.md` (derive a slug from the topic if there is no plan folder) with: context (what, who, success), the raw failure list, each deep dive, then the synthesis near the top. Tell the user the path.

Summarise in chat in three sentences: the most likely failure, the hidden assumption, the single most important revision.

## Rules

- Always set the frame explicitly and keep it; without it the output drifts back to polite risk lists.
- Always run the deep dives in parallel.
- The synthesis is the product; make it specific and actionable. Tell the user what they do not want to hear.
- One challenge per planning cycle means exactly one of `/palmface-stress-test`, `/palmface-heartwood`, `/palmface-premortem` or `/palmface-canopy`. A premortem is an alternative to the other three on the same plan, not an add-on. If a plan already went through one, recommend fixing and building rather than another round.
- If the user wants several viewpoints on a decision right now rather than failure analysis, say that is a different exercise and offer `/palmface-honest-take`.
