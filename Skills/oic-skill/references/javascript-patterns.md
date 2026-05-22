# JavaScript Patterns for OIC Libraries

OIC's Call JavaScript Function activity runs code in a Nashorn engine (ES5.1, no ES6+ features). The library file is uploaded as a Library asset and individual functions are wired into activities. The patterns in this document are what reliably works after extensive trial-and-error.

## The `var _ret` pattern (mandatory)

**Every declared function intended to run in OIC must use this pattern.** Public functions AND internal helpers. The only exception: inline lambda callbacks (e.g. the function expression passed to `String.prototype.replace`) are language-level constructs, not OIC-registered functions, and do not need the pattern.

```javascript
function someFunction(arg1, arg2) {
  var _ret;
  // ... compute ...
  if (earlyCondition) {
    _ret = earlyValue;
    return _ret;
  }
  // ... more compute ...
  _ret = mainValue;
  return _ret;
}
```

**Why it matters.** OIC's runtime infers the function's return type from the value at the return point. Without a consistent named return, OIC may bind the activity's `output_*__ret` slot to the wrong type, or fail to bind it at all. Multiple `return` statements with different expressions can produce inconsistent binding behavior across activations. The single-named-return pattern is unambiguous.

**Common mistakes:**
- Returning the expression directly: `return _str(value);` — the inferred type may not match downstream consumers.
- Multiple return points with different expressions: `if (x) return ""; return value;` — may bind inconsistently.
- Forgetting `var _ret;` at the top — Nashorn will define it implicitly but later activations may treat it as global.

## ES5.1 only — no ES6+ features

Nashorn is an older engine. Avoid:

- `let`, `const` — use `var`.
- Arrow functions — use `function () { ... }` expressions.
- Template literals — use string concatenation.
- Destructuring (`var {a, b} = obj`) — extract fields explicitly.
- `Array.from`, `Array.includes`, `Object.assign`, `Object.entries` — use ES5 loops and `for-in`.
- `Promise`, `async`/`await` — Nashorn is synchronous.
- Spread/rest (`...args`) — use `arguments` object.
- Default parameters — handle defaults inside the function body.

**Safe to use:**
- `JSON.parse`, `JSON.stringify` (yes, Nashorn supports them).
- `String.fromCharCode`, `String.prototype.replace`, `.split`, `.indexOf`.
- Regular expressions with `/.../g` and `/.../i`.
- `Math.round`, `Math.abs`, `Math.floor`, etc.
- `Date.UTC()`, `new Date(ms)` — but be careful with timezone-dependent operations.
- `java.util.Base64`, `java.lang.String` (Nashorn exposes the JVM classpath).

## No trailing commas

Nashorn rejects trailing commas in array and object literals:

```javascript
// REJECTED
var bad = [1, 2, 3,];
var alsoBad = {a: 1, b: 2,};

// ACCEPTED
var good = [1, 2, 3];
var alsoGood = {a: 1, b: 2};
```

JSON.parse is more permissive but the source code is parsed by Nashorn first.

## No console, no require, no module exports

OIC's JS runtime is a self-contained Nashorn script. There is no `console.log`, no `require()`, no `module.exports`. The file is loaded into a namespace and individual function names are registered with OIC.

Use the JavaScript Library upload mechanism for module organization — multiple files compose into one library namespace.

## Prefix conventions

Adopt a project-specific prefix for public functions. The DigiKey cash app library uses `dkcas_` for all 15 public functions:

```javascript
function dkcas_validateInvoiceForAlloc(...) { ... }
function dkcas_buildReceiptsQuery(...) { ... }
```

For internal helpers, two conventions are in use:
- **Underscore prefix** (`_str`, `_toMoney`) — used in the grandfathered cashApplicationLib internals. Visually distinct, signals private. Does NOT include the `_ret` pattern in the existing library (grandfathered).
- **Same prefix as public** (`testxtoj_xmlScalar`, `testxtoj_walkAllocations`) — used in the testxtoj_requestXmlToJson file. Same prefix, distinguishable by name only. DOES use the `_ret` pattern.

**Going forward:** every new declared function (public or internal) uses the `_ret` pattern. The choice of prefix style is project-level; pick one and stay consistent within a file.

## JSDoc — `@param` and `@returns` both named

```javascript
/**
 * One-line summary of what the function decides.
 *
 * Longer explanation if the rules are non-trivial — what counts as
 * success, what the edge cases are, what the caller should pass.
 *
 * @param {string} customerNumber The customer's Fusion account number.
 * @param {number} amount The payment amount in payment currency.
 * @returns {string} verdictCode One of "ok:valid", "halt:customer-not-found", ...
 */
function dkcas_doThing(customerNumber, amount) { ... }
```

Always name the return value (`@returns {string} verdictCode`). OIC's activity UI surfaces this name in the parameter mapper — a meaningful name saves the reader from guessing.

## Function categories — what JavaScript should and shouldn't do

The default pattern (payload-in-JS, see `interop-patterns.md`) puts most business logic in the library. JavaScript handles parsing, transformation, decisions, accumulation, and the final response shape. OIC orchestrates around the JS call.

**Good fits for a JS library function under the default pattern:**
- Parse XML payloads into JS objects (regex parser, see `dkcas_requestXmlToJson`-style implementation).
- Iterate collections of payments, allocations, items, etc., running per-element rules.
- Accumulate sums, counts, flags across iterations.
- Build a structured response object and return it as a JSON string.
- Format strings, validate dates, normalize identifiers.
- Compute a verdict code from multiple inputs.

**The orchestration (OIC side) handles:**
- REST and SOAP service invocations (these can't run inside JS).
- Stage File round trip for JS-returned JSON.
- Conditional branching that needs to fan out to different OIC activities (REST calls, SOAP calls, Map to response).
- Persisting state to OIC scope variables for the activity stream.

**When the scalar-only exception applies** (see `interop-patterns.md`), the JS library shrinks to per-decision functions. Each function takes 1-4 scalars and returns 1 scalar. OIC handles iteration and accumulation via For-Each + counters + Stitch. The DigiKey cash app library uses this exception path.

**Things JS can never do, regardless of pattern:**
- Make HTTP/SOAP calls (use OIC's REST/SOAP Invoke activities).
- Read or write OIC scope variables directly (JS only sees its arguments).
- Hold state between invocations (each call gets a fresh execution context).

## The internal helper convention

For a small set of utilities used across multiple public functions, declare them once in the library file. The cash app library has five:

```javascript
function _str(value)       { var _ret; ...; return _ret; }
function _toMoney(value)   { var _ret; ...; return _ret; }
function _moneyEq(a, b)    { var _ret; ...; return _ret; }
function _isoDateOnly(value) { var _ret; ...; return _ret; }
function _addDays(isoDate, days) { var _ret; ...; return _ret; }
```

These are not registered with OIC (no Call JavaScript Function activity points at them). They are called only by other functions in the same file.

**Convention:** if an internal helper would otherwise duplicate logic across 2+ public functions, extract it. Don't pre-emptively factor internal helpers; let them emerge from real duplication.

## Money handling

Floating-point arithmetic in JavaScript is notoriously imprecise. For currency values:

```javascript
function _toMoney(value) {
  var _ret;
  if (value === null || value === undefined || value === '') {
    _ret = 0;
    return _ret;
  }
  var n = Number(value);
  if (isNaN(n)) {
    _ret = 0;
    return _ret;
  }
  _ret = Math.round(n * 100) / 100;
  return _ret;
}

function _moneyEq(a, b) {
  var _ret;
  var diff = _toMoney(a) - _toMoney(b);
  if (diff < 0) { diff = -diff; }
  _ret = diff <= 0.005;  // half-penny tolerance
  return _ret;
}
```

The `Math.round(n * 100) / 100` pattern truncates to 2 decimal places. The `0.005` tolerance handles binary-float jitter on otherwise-equal values.

## Date handling

Avoid `new Date(isoString)` — Nashorn's Date constructor has timezone behavior that varies between JVM versions. Work with ISO strings directly:

```javascript
function _isoDateOnly(value) {
  var _ret;
  var s = _str(value);
  if (!s) { _ret = ''; return _ret; }
  if (s.length >= 10) {
    _ret = s.substring(0, 10);
    return _ret;
  }
  _ret = s;
  return _ret;
}

function _addDays(isoDate, days) {
  var _ret;
  var s = _str(isoDate);
  if (!s || s.length < 10) { _ret = ''; return _ret; }
  var y = parseInt(s.substring(0, 4), 10);
  var m = parseInt(s.substring(5, 7), 10);
  var d = parseInt(s.substring(8, 10), 10);
  if (isNaN(y) || isNaN(m) || isNaN(d)) { _ret = ''; return _ret; }
  var dt = new Date(Date.UTC(y, m - 1, d));
  dt.setUTCDate(dt.getUTCDate() + Number(days));
  var yy = dt.getUTCFullYear();
  var mm = dt.getUTCMonth() + 1;
  var dd = dt.getUTCDate();
  var mmStr = mm < 10 ? '0' + mm : '' + mm;
  var ddStr = dd < 10 ? '0' + dd : '' + dd;
  _ret = yy + '-' + mmStr + '-' + ddStr;
  return _ret;
}
```

`Date.UTC()` and the `setUTCDate()` / `getUTC*()` methods are timezone-stable.

## Regex-based XML parsing (when DOM is overkill)

For flat, well-known XML structures, regex parsing is faster and more robust than Nashorn's `javax.xml.parsers` DOM. The trade-off: it doesn't handle attributes, mixed content, or arbitrary nesting depth. Use regex when:

- The structure is flat or shallow (1-2 levels of nesting).
- The element names are known up front.
- Mixed content / attributes are absent.

See `testxtoj_requestXmlToJson.js` for a complete example. Key idioms:

```javascript
// Decode HTML/XML entities first
function _decodeXmlEntities(s) { ... }

// Walk repeating elements
var re = /<elementName>([\s\S]*?)<\/elementName>/g;
var m;
while ((m = re.exec(body)) !== null) {
  var elementBody = m[1];
  // ... process elementBody ...
}

// Extract scalar by tag name
function _xmlScalar(body, tag) {
  var esc = String(tag).replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
  var re = new RegExp('<' + esc + '>([\\s\\S]*?)<\\/' + esc + '>');
  var m = re.exec(body);
  // ... return trimmed inner text or '' ...
}
```

Note `[\s\S]*?` — `.` does NOT match newlines in Nashorn. Use `[\s\S]` for "any character including newline" with the lazy `*?` quantifier for non-greedy matching.

## Base64 handling via java.util.Base64

Nashorn exposes the JVM classpath. Base64 encode/decode:

```javascript
// Encode
var encoded = java.util.Base64.getEncoder().encodeToString(
  new java.lang.String(text).getBytes("UTF-8")
);

// Decode
var bytes = java.util.Base64.getDecoder().decode(String(encoded));
var decoded = new java.lang.String(bytes, "UTF-8") + "";
```

The `+ ""` on the end coerces the Java String back to a JavaScript string — without it, downstream concatenations may behave oddly.

This came up when designing the PR-check flow before the Stage File approach was adopted. In the final cash app design, Base64 handling moved into OIC (`decodeBase64ToReference` + Stage File) and out of JavaScript — see `interop-patterns.md`.

## Linting

Before uploading a library to OIC, lint it:

```bash
node --check cashApplicationLib.js
```

And run a Nashorn smoke test:

```bash
/usr/lib/jvm/java-11-openjdk-amd64/bin/jjs --language=es5 --no-deprecation-warning test_script.js
```

Both catch the easy mistakes (missing semicolons, undeclared variables in strict mode contexts, ES6 syntax that slipped in). For deeper checking, a Python regex walk over function declarations confirms every declared function has `var _ret;` and a single named return — see `verification-toolkit.md`.

## A complete minimal function template

When in doubt, start from this:

```javascript
/**
 * One-line summary.
 *
 * Longer explanation if needed.
 *
 * @param {string} input The input value.
 * @returns {string} result The decision string.
 */
function projectprefix_doThing(input) {
  var _ret;

  var s = String(input == null ? '' : input);
  if (!s) {
    _ret = 'empty';
    return _ret;
  }

  // ... real logic ...
  _ret = computedValue;
  return _ret;
}
```

Adapt as needed. The shape — `var _ret` at top, early-return branches that assign `_ret` first, single `_ret = X; return _ret;` at the bottom — is the bones of every OIC-friendly function.
