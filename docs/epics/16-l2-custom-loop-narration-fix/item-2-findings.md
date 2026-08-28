# Item 2 findings — text-stripping mechanism, proven live

**Script:** `item2_strip_probe.py` (this directory)
**Raw log:** `item2-run.jsonl` (this directory) — every outgoing request body and every raw API
response for a real live run, unedited
**Model:** `claude-haiku-4-5`, real API call via `ant auth login`-issued OAuth credentials
(`Authorization: Bearer`, `anthropic-beta: oauth-2025-04-20`), not the `claude` CLI

## Setup

The system prompt deliberately does **not** ask the model to stay quiet — the opposite: it's
told it "likes to explain what it's doing." The task ("look up weather in three cities, one at a
time") is shaped to invite exactly the kind of narration work-item-executor keeps producing. The
only thing suppressing narration in the resent history is `strip_text_blocks()`, which drops
`text` content blocks from an assistant turn before it's appended to `messages` for the next
request — nothing in the prompt asks for this.

## Result — read directly from `item2-run.jsonl`

| Turn | Raw response actually said | Outgoing request for the *next* turn |
|---|---|---|
| 1 | `"I'll look up the weather for each city one at a time, starting with Denver."` (real narration) | Turn 2's request history: assistant turn 1 present with `block_types=['tool_use']` only — **no text block** |
| 2 | `"Great! Denver is 58°F and partly cloudy. Now let me check Austin."` (real narration) | Turn 3's request history: assistant turn 2 present with `block_types=['tool_use']` only — **no text block** |
| 3 | No narration this turn (model's own choice — natural variation, not the mechanism) | Turn 4's request: unaffected, same pattern holds |
| 4 | `"Great! I've gathered the weather for all three cities. Here's the comparison: ..."` — the actual final answer, `stop_reason=end_turn` | Loop ends here; nothing is resent after the final turn, so this text is correctly **not** stripped |

Every intermediate turn's real, observed narration text is present in that turn's raw response
and absent from the very next request's message history. The final turn's answer text is left
intact because nothing gets resent after it — matching the plan's DoD exactly: "a live run's raw
log shows tool_use blocks only between turns, with any text block appearing solely in the final
turn."

## What this does and does not prove

- **Proven:** the mechanism itself works, live, against the real API — narration a model actually
  produces can be structurally prevented from re-entering its own context on the next turn,
  independent of any prompt instruction not to narrate.
- **Not proven here:** whether this survives a real multi-hundred-turn coding task the way
  work-item-executor actually runs (this was a 4-turn toy task with one trivial tool). Item 3
  (reimplementing enough of the executor's real tool surface and lifecycle) is where that gets
  tested for real.
- **Not proven here:** whether stripping text blocks from tool-use turns has any downstream effect
  on the model's own task coherence over a long run (e.g., losing its own scratch reasoning that
  happened to live in a text block). Worth watching in item 3, not a blocker for closing item 2.

## Credentials used

A `sk-ant-oat01-...` short-lived OAuth access token, issued via `ant auth login` against
Jonathan's Max-plan account and handed to this session directly in chat. It was written once to a
0600 file outside this repo (session scratchpad, never committed) and is not present anywhere in
this commit or in `item2-run.jsonl` — confirmed by grep before committing.
