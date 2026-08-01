# Installing `oracle-fusion-bip-generator`

This skill can be installed in any Claude environment that supports user skills. Pick the path that matches where you'll use it.

## Option 1: Claude.ai (web or mobile)

For consumer Claude.ai accounts (Pro, Team, or Enterprise plans that have skill support enabled):

1. Download the latest release `.skill` file from this repo's Releases tab.
2. In Claude.ai, navigate to Settings → Capabilities → Skills.
3. Click "Upload skill" and select the downloaded `.skill` file.
4. The skill will appear in your available skills list.
5. Start a new conversation and mention BIP, a data model, or an Oracle Fusion report — the skill will auto-load.

If skill upload isn't available on your plan, you can still copy-paste the contents of `SKILL.md` into a Claude Project's "Project knowledge" alongside the reference files.

## Option 2: Claude Code (developer CLI)

For users running Claude Code locally:

1. Clone this repo (or the parent repo if this skill is bundled alongside the `hackett-fusion` MCP server):
   ```bash
   git clone {repo-url}
   cd {repo-name}
   ```

2. Copy the skill folder into Claude Code's skills directory:
   ```bash
   # macOS / Linux
   mkdir -p ~/.claude/skills
   cp -r oracle-fusion-bip-generator ~/.claude/skills/

   # Windows (PowerShell)
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\skills"
   Copy-Item -Recurse oracle-fusion-bip-generator "$env:USERPROFILE\.claude\skills\"
   ```

3. Verify Claude Code picks it up:
   ```bash
   claude --list-skills
   ```
   You should see `oracle-fusion-bip-generator` in the list.

4. The skill auto-triggers when relevant keywords appear in your conversation. No explicit invocation needed.

## Option 3: Custom packaging (`.skill` file)

To produce a distributable `.skill` file from source:

1. Ensure you have Python 3.10+ available.
2. From this skill folder's parent directory:
   ```bash
   python -m claude_skill_packager oracle-fusion-bip-generator/
   ```
   This produces `oracle-fusion-bip-generator.skill` — a portable single-file archive.

3. Distribute the `.skill` file to teammates who can then upload it via Option 1.

If `claude_skill_packager` isn't available in your environment, you can produce a manual package:
```bash
cd oracle-fusion-bip-generator/
zip -r ../oracle-fusion-bip-generator.skill .
```
The `.skill` extension is just a renamed `.zip` containing the skill folder contents.

## Dependencies and configuration

### Required: `hackett-fusion` MCP server

Phases 1-3 of this skill require the `hackett-fusion` MCP server for SQL validation. Without it:
- The skill will still draft SQL but cannot validate it.
- Generated `.xdm` files will be syntactically correct but unverified against the target pod.

Install and configure the `hackett-fusion` MCP server first. See the parent repo's `README.md` for instructions on connecting it to your Claude environment.

### Required: target Fusion pod credentials

The `hackett-fusion` MCP server needs credentials for at least one Fusion pod (typically a dev or test pod). Production credentials are optional but recommended for the Phase 4 catalog upload feature.

### Optional: `hackett-brand-guidelines` skill

If installed, this skill is used as the default brand source for RTF templates when the user doesn't supply specific branding. Without it, RTF templates will use a generic professional layout instead of the Hackett-specific navy/gold treatment.

### Optional: `libreoffice` or `pandoc`

Only required if you want the skill to convert generated `.docx` files to `.rtf` automatically. Without these, the skill will produce `.docx` files and instruct you to save-as `.rtf` manually in Microsoft Word.

To install:
```bash
# macOS
brew install --cask libreoffice
# or
brew install pandoc

# Ubuntu / Debian
sudo apt-get install libreoffice
# or
sudo apt-get install pandoc
```

## Verification

After installation, verify the skill works end-to-end:

1. Open a new Claude conversation.
2. Type: *"Help me build a BIP report — I need a list of all GL ledgers with their period set name and currency."*
3. The skill should auto-load and respond by:
   - Acknowledging the request and confirming the intent.
   - Drafting an Oracle-style SQL query against `gl_ledgers_v`.
   - Asking to validate via `hackett-fusion:execute_sql` (if connected).
   - Asking whether you want to proceed to Data Model generation.

If you don't see this behavior, check:
- Is the skill listed in your available skills?
- Are you on a Claude environment that supports skills?
- Did the trigger keywords appear in your message? Try explicitly: *"Use the oracle-fusion-bip-generator skill to help me build a BIP report against the FUSION schema."*

## Updating

To pull a newer version of the skill:

1. **Option 1 (claude.ai):** Delete the existing skill in Settings → Capabilities → Skills, then upload the new `.skill` file.
2. **Option 2 (Claude Code):** Re-run the `cp -r` command, overwriting the existing folder.

User skills don't have an in-place update mechanism — replacement is the standard path.

## Uninstalling

1. **claude.ai:** Settings → Capabilities → Skills → delete the skill.
2. **Claude Code:** `rm -rf ~/.claude/skills/oracle-fusion-bip-generator/`

Removing the skill doesn't affect any previously-generated report artifacts under `/mnt/user-data/outputs/`.
