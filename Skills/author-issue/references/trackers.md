# Tracker mechanics

Exact commands for filing and editing the issue/work item that `SKILL.md` step 6
("File") and step 7 ("Enrich mode") call. This file has no opinion on *what* goes
in the body — that's `references/issue-body.md` — only on the tracker calls
themselves.

**Detection and auth are not repeated here.** Before any command below, follow
`references/issue-intake.md` ("Detecting the tracker" /
"Prerequisites") to decide GitHub vs. Azure DevOps from the origin remote (or the
repo's `CLAUDE.md` `Tracker:` override) and to verify `gh auth status` /
`az boards query --top 1` before running anything in this file.

Every command below was checked against its own `--help` on this machine
(`gh version 2.92.0`, `az` core `2.86.0` with the `azure-devops` extension
installed). Anything not confirmed against real output carries `[unverified]`.

## Constants

```
ADMISSION_LABEL   = epic-loop-ready      # applied to every filed item, both trackers
GH_TYPE_BUG       = bug
GH_TYPE_FEATURE   = enhancement
ADO_TYPE_BUG      = Bug
ADO_TYPE_FEATURE  = "User Story"
```

`ADMISSION_LABEL` is the epic-loop's admission gate (epic 21) — an item without it
is not eligible for pickup, whichever tracker it lives in.

## GitHub

### Label bootstrap (once per repo, cheap to re-check)

```bash
gh label list --search "epic-loop-ready" --json name -q '.[].name'
# empty output → label doesn't exist yet
gh label create epic-loop-ready --color 0E8A16 \
  --description "Admitted for epic-loop pickup — human requirements + AC present"
```
`gh label create` is idempotent-safe only with `--force` (updates color/description
instead of erroring); without it, creating an existing label errors — so always
check with `gh label list` first, don't just re-run `create`.
`verified: gh 2.92.0` (`gh label list --help`, `gh label create --help`)

### Create

```bash
gh issue create --repo <owner>/<repo> \
  --title "<title>" \
  --body-file <path-to-body.md> \
  --label "<bug|enhancement>" --label epic-loop-ready
```
Prints the created issue's URL to stdout — that line *is* the URL extraction,
nothing further to parse.
`verified: gh 2.92.0` (`gh issue create --help`)

### Edit (enrich mode, in place)

```bash
gh issue edit <n> --repo <owner>/<repo> --body-file <path-to-body.md>
```
`--body-file` replaces the whole body — enrich mode must have already merged the
preserved human-authored section into the file it points at before running this;
`gh issue edit` has no partial-body update.
`verified: gh 2.92.0` (`gh issue edit --help`)

### Read back (enrich mode, fetch step)

```bash
gh issue view <n> --repo <owner>/<repo> \
  --json number,title,body,labels,url
```
`verified: gh 2.92.0` (`gh issue view --help` — `number,title,body,labels,url`
are all valid `--json` fields per its help output)

## Azure DevOps

### Create

**`--fields`/`--description` do NOT take `@file`** — `--help` documents plain
string values only (`--description`/`-d` a string; `--fields`/`-f` space-separated
`field=value` pairs), no file-reference syntax. `[unverified — do not use @file]`.
The verified way to pass a large body without shell-quoting breakage is command
substitution, not string concatenation or `@file`:

```bash
az boards work-item create \
  --org https://dev.azure.com/<org> --project "<project>" \
  --type "Bug" \
  --title "<title>" \
  --description "$(cat description.html)" \
  --fields "Microsoft.VSTS.Common.AcceptanceCriteria=$(cat ac.html)" "System.Tags=epic-loop-ready" \
  --output json
```
`--type` is `Bug` or `"User Story"` per `ADO_TYPE_*` above. `"$(cat file)"` keeps
the file's content as one shell word inside the outer double quotes — embedded
quotes/backticks in the body are not re-parsed by the shell, so this is safe where
hand-escaping a multi-paragraph body is not.
`verified: az boards work-item create --help` — confirms `--type`, `--title`,
`--description`/`-d`, `--fields` (repeatable per field), `--output json`; the
`$(cat file)` substitution itself is standard shell, not an ADO-specific claim.

### Update (enrich mode)

```bash
az boards work-item update --id <n> \
  --description "$(cat description.html)" \
  --fields "Microsoft.VSTS.Common.AcceptanceCriteria=$(cat ac.html)" \
  --output json
```
`verified: az boards work-item update --help`

### Read back (enrich mode, fetch step)

```bash
az boards work-item show --id <n> --output json
```
`verified: az boards work-item show --help`

### URL extraction

ADO's JSON response carries two different URLs and they are not interchangeable:
- `.url` — the REST API resource URL (`.../_apis/wit/workItems/<n>`), not
  browsable.
- `._links.html.href` — the human-facing web URL to print/link.

**Use `._links.html.href`.** `[unverified here]` — not confirmed against a live
`az boards work-item create`/`show` response on this machine (no scratch ADO item
was created to check it); this follows documented Azure DevOps REST API work item
shape. Confirm against the first real response and correct this note if it
differs.

### Markdown → HTML for `Description` / `AcceptanceCriteria`

Both fields render as HTML in ADO's UI, not Markdown — feeding them raw Markdown
leaves literal `**`/`#`/`- ` characters visible. Convert before filing:

```bash
# Preferred, if installed:
pandoc -f gfm -t html body.md -o body.html
```
`[unverified — pandoc not installed here]`. Fallback confirmed working on this
machine, no local install required:
```bash
npx --yes marked -i body.md -o body.html
```
`verified: marked 18.0.12 via npx` (`npx --yes marked --help`; ran
`npx --yes marked --version` successfully on this machine).
