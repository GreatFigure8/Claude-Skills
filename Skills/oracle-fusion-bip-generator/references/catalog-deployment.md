# BIP Catalog Deployment (Phase 4)

This reference covers the optional Phase 4 catalog upload: pushing the generated `.xdm` and `.rtf` artifacts into the live BIP catalog via the `hackett-fusion` MCP server's catalog tools. Phase 4 is opt-in; default behavior is to stop after file delivery.

## Session required

All tools in this reference require an active Fusion session — they will return `{"error": "no_session", ...}` if called before `start_session`. The session carries the credentials and target host; without it there's no concept of "which pod do I upload to." See Step 0 of `SKILL.md` for the session protocol.

## MCP tool reference

All catalog tools live on the `hackett-fusion` MCP server alongside the existing `execute_sql`, `run_bip_report`, `identify_environment`, and session management tools. They share the active session's credentials — there is no per-tool authentication.

### High-level (used during Phase 4)

#### `hackett-fusion:upload_data_model`

Packages a raw `.xdm` (data model XML) into a BIP `.xdmz` archive and uploads it to the catalog.

**Inputs:**
- `path` (string, required) — absolute catalog path of the data model. Example: `/Custom/Financials/Receivables/ar-invoice-agingDM.xdm`. Must end in `.xdm`. No `/Shared Folders/` prefix.
- `xdm_content` (string, required) — full XDM XML content as a string. The MCP server packages this into a `.xdmz` archive with the required `~metadata.meta` and `~security.sec` companion files before upload.
- `overwrite` (boolean, optional, default `false`) — whether to replace an existing data model at that path. If `false` and an object exists, the call returns an error.

**Output (JSON):**
- `status`: `"ok"` or `"error"`.
- `catalog_path`: full path of the uploaded object.
- `bytes_uploaded`: size of the `.xdmz` package.
- `message`: human-readable confirmation or error detail.

#### `hackett-fusion:upload_report`

Packages a BIP `.xdo` report descriptor and (optionally) an RTF template into a `.xdoz` archive and uploads it to the catalog. The RTF template is embedded inside the `.xdoz` — no separate template upload call is needed.

**Inputs:**
- `path` (string, required) — absolute catalog path of the report. Example: `/Custom/Financials/Receivables/ar-invoice-aging.xdo`. Must end in `.xdo`.
- `data_model_path` (string, required) — absolute catalog path of the previously-uploaded data model. Example: `/Custom/Financials/Receivables/ar-invoice-agingDM.xdm`.
- `report_title` (string, optional) — friendly display title in the catalog UI. Defaults to the filename portion of `path` without the `.xdo` extension.
- `description` (string, optional) — long description for catalog metadata.
- `rtf_content` (string, optional) — full RTF template content as a string. If supplied, the template is embedded in the `.xdoz` and bound as the default layout. If omitted, the report is uploaded data-only.
- `template_name` (string, optional, default `"Default RTF"`) — internal name used to bind the template in the `.xdo` descriptor.
- `template_locale` (string, optional, default `"en_US"`).
- `overwrite` (boolean, optional, default `false`).

**Output (JSON):**
- `status`: `"ok"` or `"error"`.
- `catalog_path`: full path of the uploaded report.
- `template_attached`: boolean — whether an RTF was embedded.
- `bytes_uploaded`: size of the `.xdoz` package.
- `message`: human-readable confirmation or error detail.

### Low-level primitives (used as needed)

#### `hackett-fusion:catalog_object_exists`

Pre-flight check before upload, or used to verify a deployment succeeded.

**Inputs:** `path` (string, required) — absolute catalog path.
**Output (JSON):** `{exists: bool, path: str}`.

#### `hackett-fusion:catalog_delete_object`

Used for rollback (if a downstream step in the deployment fails) or to clear an existing object before re-uploading.

**Inputs:** `path` (string, required) — absolute catalog path.
**Output (JSON):** `{status: "ok"|"error", path: str, message: str}`.

**Important:** This is destructive. Always confirm with the user before calling, even during an error-recovery flow. Refuse to delete from production-fingerprinted environments without separate explicit confirmation.

#### `hackett-fusion:catalog_create_folder`

Creates a folder in the BIP catalog. Useful if the target deployment path's parent folder doesn't exist yet.

**Inputs:** `path` (string, required) — absolute folder path, no trailing slash.
**Output (JSON):** `{status: "ok"|"error"|"already_exists", path: str, message: str}`.

### Smoke test (existing tool)

#### `hackett-fusion:run_bip_report`

Runs a deployed report by absolute path to confirm the deployment worked. Already exists on the server.

**Inputs:** `path` (string, required) — `.xdo` path. `fmt` (string, optional) — output format. Omit to use the report's default.
**Output:** the report bytes, decoded as UTF-8 text. For binary formats (PDF), the bytes are returned with replacement of invalid sequences — this isn't a problem for smoke-test purposes (we just want to confirm execution succeeds and content is non-empty).

## Deployment workflow

1. **Identify environment.** Call `hackett-fusion:identify_environment` and echo the fingerprint to the user.

2. **Confirm target path.** Ask the user for the BIP catalog folder. Common patterns:
   - `/Custom/Financials/Receivables/`
   - `/Custom/Financials/Payables/`
   - `/Custom/HCM/`
   - `/Custom/{Client}/`

3. **Production guard.** If the environment fingerprint indicates production, refuse to proceed without a separate explicit "yes, push to prod" confirmation. Even if upfront blanket permission was given, prod always re-prompts.

4. **Folder pre-flight.** Call `catalog_object_exists` on the target folder. If it doesn't exist, call `catalog_create_folder` with user confirmation.

5. **Object pre-flight.** Call `catalog_object_exists` on the data model path AND the report path. If either exists and the user didn't explicitly confirm `overwrite=true`, halt and confirm.

6. **Upload data model.** Call `upload_data_model` with the `.xdm` content. Capture the returned `catalog_path`.

7. **Upload report (with template).** Call `upload_report` with the data model path from step 6 and the RTF content. The template is embedded inside the `.xdoz`.

8. **Smoke test.** Call `run_bip_report` with the report path and any required parameter defaults. Verify:
   - Job submits without error.
   - Output is non-empty.
   - Sample output excerpt looks correct.

9. **Receipt.** Emit `{report_short_name}_deployment.md` in the current `v{N}` folder. Include:
   - Target environment fingerprint and timestamp.
   - Catalog paths of all uploaded objects.
   - Smoke test result.
   - Rollback instructions.

## Failure handling

If any upload step fails, halt immediately. Do not attempt subsequent steps. Report to the user:
- Which step failed (`upload_data_model`, `upload_report`, or `run_bip_report` smoke test).
- The server error message verbatim.
- Whether prior steps in this deployment succeeded (so the user knows what needs cleanup).
- Offer two paths forward: retry the failed step, or roll back the successful steps (using `catalog_delete_object`).

Never leave a partial deployment in the catalog without explicit user acknowledgement.

## Rollback receipt template

Every deployment receipt should include rollback instructions. Standard pattern:

```
To roll back this deployment, run from the same Claude session (oldest first):

1. catalog_delete_object("{report_path}")        # Removes .xdo + embedded template
2. catalog_delete_object("{data_model_path}")    # Removes .xdm

Or manually via the BIP catalog UI:
- Navigate to {catalog_path}
- Right-click {report_short_name}.xdo → Delete
- Right-click {report_short_name}DM.xdm → Delete
```

## Pre-flight checklist (before any catalog write)

- [ ] Environment fingerprint echoed and confirmed.
- [ ] Target catalog path confirmed.
- [ ] Report short name confirmed.
- [ ] Production environment? Separate "yes, push to prod" confirmation received.
- [ ] All `v{N}` artifacts (`.xdm`, `.rtf`, `_README.md`) exist on disk and are validated.
- [ ] Data source name embedded in the XDM matches an existing data source in the target pod's BIP Administration.
- [ ] No existing object at target path, OR `overwrite=true` is explicitly confirmed.

## Underlying SOAP transport (for reference)

The MCP tools above abstract the SOAP calls away. For debugging or for the parallel Admin Deploy CLI (per `.claude/plans/fusion-mcp-provisioning-platform.md`), the underlying operations are on the BIP `CatalogService` SOAP endpoint:

- Endpoint: `{host}/xmlpserver/services/v2/CatalogService` (parallel to the existing `ReportService` endpoint used by `execute_sql` and `run_bip_report`).
- Auth: same Basic auth via `<userID>` / `<password>` SOAP envelope elements as the existing tools.
- Operations used:
  - `uploadObject(reportObjectAbsolutePath, objectType, objectZippedData)` — uploads a base64-encoded `.xdmz` / `.xdoz`.
  - `objectExist(reportObjectAbsolutePath)` — returns boolean.
  - `deleteObject(reportObjectAbsolutePath)` — destructive.
  - `createFolder(folderAbsolutePath)` — creates a catalog folder.

## `.xdmz` / `.xdoz` package format (for reference)

For consistency with Oracle's BIP catalog format (and matching what `HK_SQL_RUNNER.xdmz` looks like inside the repo at `fusion/bip/HK_SQL_RUNNER/`), the MCP server packages content as:

**`.xdmz` archive contents:**
- `_datamodel.xdm` — the XDM XML content.
- `~metadata.meta` — display name + path metadata.
- `~security.sec` — default permission policies for BIAuthor / BIAdministrator / BIConsumer roles.

**`.xdoz` archive contents:**
- `_report.xdo` — report descriptor pointing at the data model URL.
- `xdo.cfg` — empty config (default fonts).
- `~metadata.meta` — display name + path metadata.
- `~security.sec` — default permission policies.
- (optional) RTF template embedded as a side file referenced from `_report.xdo`'s `<templates>` element.

The packaging is handled by `src/hackett_fusion_mcp/bip_packager.py` in the MCP server source — no need for the skill to construct these archives manually.
