# Oracle Fusion HCM / Time & Labor + OIC Notes (captured 26 Aug 2026)

These are notes from one prior review (Archrock INT0830, an IFS→OIC→Fusion HCM
time-clock feed), kept as a starting point for search terms and a sense of what to look
for. **Do not cite this file in a report.** Fetch the current `docs.oracle.com` page for
anything you use — release-specific paths (`11.13.18.05` below), required-field lists,
and query-parameter support all change across Oracle releases.

## `timeEventRequests` (POST) — real-time clock punch import

- `POST /hcmRestApi/resources/11.13.18.05/timeEventRequests`
- Required header fields: `requestNumber` (≤80), `requestTimestamp` (≤80), `sourceId`
  (≤40). Required per-event fields: `eventDateTime` (≤150, ISO 8601 **with UTC
  offset**), `reporterId` (≤80), `reporterIdType` (≤30, one of `BADGE`, `PERSON`,
  `PERSONID`, `ASSIGNMENT`). Optional: `deviceId`, `supplierDeviceEvent` (must be a code
  in lookup `ORA_HWM_TCD_SUPPLIER_EVENTS`, and by Oracle's convention should be
  prefixed with the supplier's own lookup code), `timeEventAttributes[]` (`name`/`value`
  pairs, e.g. `PayrollTimeType` / a payroll time type name).
- A `201` means the event was accepted into the time repository, **not** that a time
  entry now exists. Search: "REST API for Oracle Fusion Cloud HCM Create a time event
  request".

## Downstream processing (why a 201 isn't the whole story)

- Oracle's own description of the pipeline: import → validate against Time Device Event
  Mappings → save to repository → the scheduled **Generate Time Cards from Time
  Collection Device** process turns valid events into (incomplete/complete) time
  entries and turns invalid ones into **time entry exceptions** for a time and labor
  manager to resolve. An integration that reports "Success" at the 201 and never
  surfaces exception outcomes is telling the caller less than it thinks it is. Search:
  "Generate Time Cards from Time Collection Device Process", "Time Device Event
  Mappings", "Overview of Time Collection Device and Web Clock Event Processing".

## `workers` (GET) — the collection query mechanics that matter

- Query parameters live in the query string and are declared/mapped separately from any
  path template parameter in the OIC REST adapter: `q` (documented queryable attributes
  include `PersonNumber`; syntax `q=PersonNumber='12345'` or `q=PersonNumber=12345`),
  `finder` (e.g. `findByPersonId`), `fields` (project only what's needed — cuts response
  size dramatically), `onlyData` (drop the `links[]` section), `limit`/`offset`.
- `count` in the response is documented as "the number of resource instances returned
  in the current range" — i.e. page size, not a total-matches count. A `count = 0` check
  intended to mean "not found" only works if a real filter actually reached the server.
- **The bug to check for by default:** a `q` expression built in an XSLT map and then
  assigned into a URI **template** parameter (declared `{like this}` in the resource
  path) rather than a genuine query parameter. OIC's REST adapter keeps these as
  separate constructs (see "REST Adapter Trigger/Invoke Request Parameters page" in
  Oracle's OIC docs); a filter placed in a template slot is not applied server-side, and
  the collection returns its default (often unfiltered, full-representation) page.
  Confirm/deny by reading `ConnectivityProperties/RestAPI/http.target.endpoint.uri` in
  the invoke's response, exposed by the adapter's `RESTOUTRES` connectivity properties.

## `timeRecordEventRequests` (POST) — the synchronous alternative

- Takes a record shape (`startTime`/`stopTime` or a `measure`, `reporterId`/
  `reporterIdType`, `timeRecordEventAttribute[]`) rather than discrete in/out punches,
  plus `processMode` (`TIME_SAVE` / `TIME_SUBMIT`) and `processInline` (`Y`/`N`).
- `processInline=Y` processes synchronously and returns `eventStatus` +
  `timeRecordEventMessage[]` in the same response — useful when the caller wants a real
  validation outcome immediately, but it bypasses Time Device Event Mappings/rules and
  uses time-entry/submission rules instead; a genuinely different processing path, not a
  drop-in replacement. `processInline=N` lands in an interface table and needs a
  separate **Process Imported Time Entries** run. Community reports (Cloud Customer
  Connect) describe null `timeRecordId`/`timeRecordVersion` and JBO errors on some
  inline-mode records — worth a DEV-pod prototype before committing to this path.

## OIC platform mechanics worth checking on every review

- **Chatty integrations** are a named Oracle anti-pattern: an invoke inside a loop, or
  any avoidable extra round-trip to the target on the synchronous path. Oracle's own
  guidance: batch where the target API allows it, and don't call a target twice when
  once suffices.
- **Fault handling**: best practice is a scope around every invoke with its own fault
  handler, plus a global fault handler as the last resort; use Fault Return to surface a
  real HTTP status to the caller rather than letting an unhandled fault produce OIC's
  generic 500. Check whether every invoke sits inside a scope, and whether a global
  fault handler exists at all — a common gap is one scope wired with a catch and a
  second, otherwise-identical invoke with none.
- **Adapter choice**: Oracle recommends the purpose-built application adapter (e.g. the
  HCM Cloud Adapter) over the generic REST adapter for that application's own resources
  where available — the generic adapter requires every endpoint's schema to be
  hand-defined from a pasted sample, which is exactly how a stale or incomplete response
  schema (and bugs like the template-parameter one above) tend to get baked in.
- **Connection reuse**: too many near-duplicate connections to the same target is a
  named anti-pattern; check whether connections are shared/custodian-managed or
  proliferated per-developer.
