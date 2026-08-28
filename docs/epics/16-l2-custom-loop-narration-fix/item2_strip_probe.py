"""
Epic 16, item 2: proves that a hand-rolled Messages API loop can strip an
assistant's intermediate text blocks from message history before each
subsequent turn, so self-narration cannot re-enter the model's own context.

Throwaway diagnostic — not wired into anything, not imported by any other
module in this repo.

Method:
  - A manual tool-use loop (not the SDK's Tool Runner, not the Agent SDK) —
    deliberately, because stripping history between turns requires owning
    the loop.
  - The system prompt does NOT tell the model to stay quiet — the opposite:
    it's given a task shaped to invite commentary between sequential tool
    calls, so any stripping observed is the loop's doing, not the model
    choosing not to narrate.
  - After every turn, two things are logged separately:
      1. RAW response as the API actually returned it (proves what the
         model actually said, narration included).
      2. OUTGOING request body for the next turn (proves what was actually
         resent) — assistant text blocks from prior turns must be absent.
  - strip_text_blocks() is the only thing that touches history between
    turns.

Usage:
  ANTHROPIC_AUTH_TOKEN=<oauth access token> python3 item2_strip_probe.py [log_path]
  (or ANTHROPIC_API_KEY=<key> for a static-key credential instead)
"""
import json
import os
import sys

import anthropic

LOG_PATH = sys.argv[1] if len(sys.argv) > 1 else "item2-run.jsonl"

client_kwargs = {}
if os.environ.get("ANTHROPIC_AUTH_TOKEN"):
    client_kwargs["auth_token"] = os.environ["ANTHROPIC_AUTH_TOKEN"]
    client_kwargs["default_headers"] = {"anthropic-beta": "oauth-2025-04-20"}
client = anthropic.Anthropic(**client_kwargs)  # falls back to ANTHROPIC_API_KEY if set

FAKE_WEATHER = {
    "Denver": "58F, partly cloudy",
    "Austin": "91F, clear",
    "Portland": "63F, light rain",
}

TOOLS = [
    {
        "name": "get_weather",
        "description": "Get the current weather for a named city.",
        "input_schema": {
            "type": "object",
            "properties": {"city": {"type": "string"}},
            "required": ["city"],
        },
    }
]

SYSTEM = (
    "You are a helpful, conversational assistant. You like to explain what "
    "you're doing and share brief observations as you work through a task "
    "step by step. There is no instruction to stay quiet."
)

USER_TASK = (
    "Look up the current weather in Denver, then Austin, then Portland — "
    "one city at a time, calling the tool separately for each city rather "
    "than all at once. After you have all three, write one sentence "
    "comparing them."
)


def call_tool(name, tool_input):
    if name == "get_weather":
        return FAKE_WEATHER.get(tool_input["city"], "unknown city")
    raise ValueError(name)


def strip_text_blocks(content):
    """Keep only tool_use blocks from an assistant turn — the mechanism
    under test."""
    return [b for b in content if b.get("type") == "tool_use"]


def to_jsonable(obj):
    return obj.model_dump() if hasattr(obj, "model_dump") else obj


def main():
    messages = [{"role": "user", "content": USER_TASK}]
    log = open(LOG_PATH, "w")
    turn = 0
    max_turns = 8

    while turn < max_turns:
        turn += 1
        log.write(json.dumps({"turn": turn, "kind": "outgoing_request", "messages": messages}, default=str) + "\n")
        log.flush()

        response = client.messages.create(
            model="claude-haiku-4-5",
            max_tokens=512,
            system=SYSTEM,
            tools=TOOLS,
            messages=messages,
        )

        raw = to_jsonable(response)
        log.write(json.dumps({"turn": turn, "kind": "raw_response", "response": raw}, default=str) + "\n")
        log.flush()

        assistant_content = [to_jsonable(b) for b in response.content]

        if response.stop_reason != "tool_use":
            messages.append({"role": "assistant", "content": assistant_content})
            log.write(json.dumps({"turn": turn, "kind": "final_answer", "stop_reason": response.stop_reason}) + "\n")
            break

        # THE MECHANISM UNDER TEST: strip text blocks before this turn ever
        # becomes part of history sent on the next request.
        messages.append({"role": "assistant", "content": strip_text_blocks(assistant_content)})

        tool_results = []
        for block in assistant_content:
            if block.get("type") == "tool_use":
                result = call_tool(block["name"], block["input"])
                tool_results.append({"type": "tool_result", "tool_use_id": block["id"], "content": str(result)})
        messages.append({"role": "user", "content": tool_results})

    log.close()
    print(f"Done after {turn} turns. Log: {LOG_PATH}")


if __name__ == "__main__":
    main()
