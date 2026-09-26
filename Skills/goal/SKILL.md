---
name: goal
description: Pursue a stated objective with a named skill until that skill's own completion condition is met, autonomously — "/goal using SKILL OBJECTIVE". Parses the skill name after "using", loads that skill with the objective as its argument, and keeps working through its phases without asking "shall I continue?", stopping only where the skill itself stops (done, blocked on a decision only Jonathan can make, or its token-budget gate). Use whenever Jonathan types /goal, says "goal:", "using SKILL …", "keep going until …", "run SKILL until …", or "execute until all the planned sprints are completed". Do NOT use to invent a process — if no skill is named and none clearly fits the objective, say so and ask which skill to use.
---

# Goal

A one-line launcher. It turns `/goal using dev-story-flow execute until all the planned
sprints are completed` into a call to the `dev-story-flow` skill with the objective
`execute until all the planned sprints are completed`, and then gets out of the way.

## Procedure

1. **Parse.** The argument is `[using <skill-name>] <objective>`. The skill name is the single
   token after `using`; the objective is everything else, verbatim. A `/<skill-name>` token
   anywhere in the argument (`/goal execute /dev-bother-me-nope for …`) names the skill the
   same way — but only when it exactly matches a loaded skill's name (so `/api/users` in an
   objective is never a skill); the objective is the argument with that token removed.
   Without either, match the
   objective's nouns against the loaded skills' descriptions ("sprint", "story" → dev-story-flow
   when `docs/sprints` exists, else dev-story-sprint; "epic", "issue" → dev-epic-workflow;
   "release" → release). State the choice in one line. No clear match → ask, in one line.
2. **Load.** `Skill({skill: "<skill-name>", args: "<objective>"})`. If the skill is not in the
   available list, say so in one line and stop — never approximate a skill from memory.
3. **Pursue.** Follow the loaded skill exactly, including its silence rules, model-table rule,
   claim/hand-off mechanics, and budget gate. The objective is the completion condition:
   "until all the planned sprints are completed" means loop the skill's execute phase while
   its work-discovery step still returns work. Never idle, never ask permission to continue,
   never re-post a plan the skill already posted.
4. **Stop only where the skill stops.** Done (its closing message), blocked (its blocker
   message), or its budget gate (its prep-for-clear prompt). Add nothing after that message.

## Rules

- `goal` owns no process. Every rule that governs the work comes from the skill it loaded.
- The objective text is passed through untouched — the skill parses it, not `goal`.
- Resuming after a `/clear` is the same `/goal …` line again; file-driven skills re-ground
  from disk and continue.
