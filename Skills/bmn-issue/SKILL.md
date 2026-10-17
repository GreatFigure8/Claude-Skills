---
name: bmn-issue
description: Create a GitHub story issue for the dev-bother-me-nope pipeline from a one-line summary. Use when the user runs /bmn-issue <summary> or asks to file a story issue for bmn. The text after the command is the summary; the skill drafts the template fields and creates the issue with the bmn label.
---

# bmn-issue

Turns a one-line summary into a GitHub story issue in the current repo, shaped like the
repo's "Story for dev-bother-me-nope" template (`.github/ISSUE_TEMPLATE/story.yml`) and
labelled `bmn`, so dev-bother-me-nope can read it as a story.

## Steps

1. **Summary.** The text after `/bmn-issue` is the summary. If it is empty, ask for one line
   and stop there. Do not invent a summary.

2. **Repo.** `gh repo view --json nameWithOwner -q .nameWithOwner` in the working directory.
   Use that `owner/repo` for every `gh` call. If it fails, say the directory is not a GitHub
   checkout and stop.

3. **Draft the fields.** Expand only from what the summary says. Anything you infer is marked
   `(inferred)` so Jonathan can see it.
   - **Title:** `[story] <summary>`, keeping the summary's wording.
   - **Goal:** one or two sentences restating what should be true when this is done.
   - **Acceptance criteria:** 2 to 5 testable lines, each starting `- [ ]`. Each is one
     outcome a test can check. Mark a line `(inferred)` if you added it beyond the summary.
   - **Constraints and out of scope:** only what the summary states, else `None stated.`
   - **Touches a screen a person looks at?:** `Yes` if the summary names a page, screen,
     button, form, or other visible UI; otherwise `No`. Mark it `(inferred)`.

4. **Write the body** to `<scratchpad>/bmn-issue-body.md` in the same headings the template
   renders, so the issue reads like one filed from the form:

   ```
   ### Goal

   <goal>

   ### Acceptance criteria

   <criteria>

   ### Constraints and out of scope

   <constraints>

   ### Touches a screen a person looks at?

   <Yes|No>
   ```

5. **Create the issue.** Ensure the label exists, then create the issue:
   `gh label create bmn --color 5319e7 --description "Work to run through dev-bother-me-nope" --repo <owner/repo> || true`
   `gh issue create --repo <owner/repo> --title "<title>" --body-file <body file> --label bmn`

6. **Report.** Print the issue URL, then the lines you marked `(inferred)` so Jonathan can
   edit any of them. Don't restate the whole body. If he wants a change, edit the issue with
   `gh issue edit <n> --repo <owner/repo> --body-file <file>`, not a new issue.

## Rules

- Create the issue only from the summary the user gave with the command. Don't pull in text
  from other sources.
- Don't ask follow-up questions unless the summary is empty. Draft, create, and list the
  inferred parts.
- Don't set assignees, milestones, or projects unless asked.
