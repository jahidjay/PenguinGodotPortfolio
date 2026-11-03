# ADR-0007: Online Services — Transport, Adapters, Steam GDExtension Exception and Hosting

## Status
**Accepted (2026-11-03)** — the architecture decision is accepted with the design set at the Concept → Pre-Production gate. **Build gates unchanged:** no server is built until (1) the cross-platform replay spike of ADR-0003 (Online GDD AC-14) passes, (2) the transport spike (V1–V3 below) passes, and (3) `/security-audit` has reviewed the items in "Security review items". Online is Stretch tier, so these gates are not on the MVP path.

## Date
2026-11-03 (revised 2026-11-03, UX amendments wave 5: `HttpAdapter` platform wording - all platforms technically capable, enabled on PC and Web only; Switch and mobile ship no adapter and do not list the Online tab)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (latest patch 4.7.2), GL Compatibility renderer; headless Linux export for verifier workers |
| **Domain** | Networking / Platform / Security |
| **Knowledge Risk** | HIGH — 4.7 is beyond the LLM baseline (~4.3) |
| **References Consulted** | `docs/engine-reference/godot/*` (no networking, HTTPRequest, Web export or GDExtension-on-Web coverage); HTTPClient class reference (latest + 4.3, web search 2026-11-03): CORS note for Web exports, "TLS support is currently limited to TLSv1.2 and TLSv1.3" (latest), no certificate pinning/revocation; Godot forum (4.5): official Web templates ship without GDExtension support |
| **Post-Cutoff APIs Used** | None knowingly. Relies on `HTTPRequest` (`request_raw`, `timeout`, `request_completed`), `Crypto.generate_random_bytes`, `FileAccess` on `user://` (IndexedDB on Web), `PackedByteArray.compress(FileAccess.COMPRESSION_ZSTD)` (owned by ADR-0003), `Engine.has_singleton` / `ClassDB.class_exists`, GodotSteam GDExtension. All **UNVERIFIED for 4.7**. |
| **Verification Required** | (1) `HTTPRequest` on Web: HTTPS via browser fetch, custom `Authorization` header passes a CORS preflight, binary body via `request_raw`, from an itch.io iframe (Online AC-49). (2) Desktop TLS: Godot's bundled CA bundle validates the chosen host's certificate (Online OQ13). (3) A GodotSteam GDExtension build exists for 4.7.x on Windows and Linux, and its auth-ticket-for-Web-API call name (Steamworks `GetAuthTicketForWebApi`) — UNVERIFIED. (4) The game runs unchanged when the Steam extension is absent. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (GDScript only; node-free logic; this ADR amends Decision 1 with a scoped exception); ADR-0003 (determinism, replay format and cross-platform verification — the trust anchor); ADR-0004 (scene host: where the `OnlineHost` node lives, `process_mode ALWAYS`) |
| **Enables** | Online leaderboards and Boss Rush epic (system 32): client `OnlineService`, adapters, upload queue, board cache; server epic |
| **Blocks** | Any server work; the Steam export preset |
| **Ordering Note** | Order: ADR-0003 spike → this ADR's transport spike → `/security-audit` → server epic. The client side (NullAdapter, queue, cache, fake adapter tests) can be built before the server exists. |

## Context

### Problem Statement
The Online leaderboards GDD (system 32) chose a **custom verifier service as the single source of truth** (Rule 4, option C), with platform adapters for identity and friends only (Rule 6). Three technical choices were deferred to an ADR (GDD Rule 7, Amendment 12, OQ2, OQ8, OQ13): the client transport and adapter shape, the **Steamworks GDExtension** (which conflicts with "GDScript only", CLAUDE.md / ADR-0001 Decision 1), and **hosting, data region and privacy basics**. They must be fixed before any server work, because they decide the legal footprint, the cost and the attack surface.

### Constraints
- Gameplay and UI are GDScript only; the official Web export must keep working (ADR-0001).
- Online never touches the 60 Hz tick, never blocks play, is opt-in (default off) and queues offline (GDD Rules 1, 14, 29–33).
- Solo developer: the backend must be one small service that one person can run, back up and patch.
- Players are expected in Bangladesh, India and worldwide; the developer's legal exposure is unknown (→ `/security-audit`). Collect as little personal data as possible (GDD Rule 17).
- The verifier runs the **exact** game build headless (GDD Rule 24.4), so workers must run Godot binaries (Linux x86-64).

### Requirements
- Async request/response with polling outside the tick; deterministic tests with a fake adapter and no network (GDD Test setup).
- HTTPS on desktop and Web; Web from itch.io and an own site.
- Steam users: identity by Steam ticket and Steam friends, no extra account.
- Right to erase, consent versioning, minimal data, short retention (GDD Rules 14–19).

## Decision

### 1. Trust model (confirms GDD Rule 4 option C)
The custom verifier service is **authoritative**. Platform services provide identity and friends only. Nothing the client sends is trusted until a replay re-simulation (ADR-0003) matches the claim. The client holds no key able to publish a score.

### 2. Client architecture
- **`OnlineService`** (node-free `RefCounted`): eligibility (GDD Rule 1), `UploadQueue`, `BoardCache`, consent/version checks, backoff (F6). It talks only to a `LeaderboardAdapter`.
- **`LeaderboardAdapter`** (node-free `RefCounted` interface, GDD Rule 5): `identity()`, `friends()`, `fetch()`, `fetch_around()`, `submit()`, `status()`, `delete_my_data()`, `poll() -> Array[OnlineEvent]`. Every call returns a `request_id` immediately; results arrive only through `poll()`.
- **Adapters:** `HttpAdapter` (**technically capable on all platforms - enabled on PC and Web only**: Web, itch.io and desktop builds. **Switch / Switch 2 and iOS / Android ship no adapter at launch**: they get `NullAdapter`, the Online tab is not listed, and local boards work as normal, until a per-platform adapter ships. Decided 2026-11-03, wave 5: the Online GDD's platform scope wins; Rule 6 there is the authority), `SteamAdapter` (wraps `HttpAdapter`, adds the Steam ticket and Steam friends), `NullAdapter` (every call → `UNAVAILABLE` at once; used when not consented, offline-forced, no service configured, **or on a platform with no adapter**), `FakeAdapter` (tests: scripted responses and latency).
- **`HttpTransport`** (the only Node): owns a small pool of `HTTPRequest` nodes (**max 2 concurrent**), `timeout = request_timeout_s` (10). It lives under the `OnlineHost` node (ADR-0004), `process_mode = ALWAYS`, so menus during pause still work.
- **Polling:** `OnlineHost._process` calls `adapter.poll()` **once per rendered frame**; `GameLoop` never calls into online code. During the `Stage` and `Tally` session states, uploads are **not started** (avoids frame hitches on Web where the request runs on the main thread); queued work resumes on Results / menus (GDD Rule 32 spirit).
- **Selection:** at boot, `Steam` build + extension present + Steam running → `SteamAdapter`; otherwise, **on PC or Web**, `HttpAdapter` if `online.enabled` and consent version is current; else `NullAdapter`. On **Switch / Switch 2 and mobile** the selection is always `NullAdapter` at launch (no adapter is built into those presets), and the UI does not list the Online tab (Online GDD Rule 6, Menus P22).

### 3. Wire protocol
- HTTPS only, JSON for metadata, binary for replays. Versioned paths `/v1/...`.
- Endpoints: `POST /v1/installs` (consent → returns `install_id`, `install_token`, `friend_code`), `POST /v1/submissions` (body = the `.mjr` replay, `Content-Type: application/octet-stream`; the claim is the replay footer, ADR-0003), `GET /v1/submissions/{id}`, `GET /v1/boards/{key}?scope&offset&count`, `GET /v1/boards/{key}/around`, `POST /v1/friends`, `DELETE /v1/me`, `POST /v1/reports`.
- **Auth:** `Authorization: Bearer <install_token>` (random 256-bit, server stores a hash). The token proves *who* (needed so nobody can erase or impersonate another install by guessing its id); it cannot mint scores. Steam: `POST /v1/installs/steam` with a Steam Web-API ticket; the server validates it with Steam's Web API and returns the same kind of token; the Steam id is stored only as a keyed hash (HMAC with a server secret).
- Server replies carry **reason codes only** (GDD Rule 25); the client localizes.
- No cookies, no third-party scripts, no analytics.

### 4. Web specifics
- `HTTPRequest` on Web goes through the browser (fetch/XHR): **TLS is the browser's**; certificate handling is not Godot's.
- **CORS:** the API answers preflight (`OPTIONS`) and sets `Access-Control-Allow-Origin` to an **allow-list** (own site origin, the itch.io HTML game origin — the exact itch.io iframe origin, e.g. `*.itch.zone`, is UNVERIFIED and is measured in V2), `Access-Control-Allow-Headers: Authorization, Content-Type`, `Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS`, no credentials. `*` is not used because the API accepts bearer tokens.
- Storage: `user://` on Web is browser storage (IndexedDB); if storage is blocked (private mode, third-party iframe storage partitioning), the adapter falls back to `NullAdapter` with the one-line notice (GDD edge case, AC-49).
- Mixed content is impossible: the API is HTTPS-only with HSTS.

### 5. Desktop TLS
- Godot's own TLS (HTTPClient: TLS 1.2/1.3, no pinning, no revocation). Use the engine's bundled CA certificates; **no custom certificate bundle and no pinning** (pinning breaks on host certificate rotation and cannot be updated for old builds). The host must serve a certificate chained to a mainstream public CA (Let's Encrypt or equivalent). V3 verifies.

### 6. Steam GDExtension — scoped exception to ADR-0001 Decision 1
- **Allowed:** the **GodotSteam GDExtension** (prebuilt, MIT licence; not the GodotSteam module build, so the standard editor and official export templates stay in use), pinned to a release built for Godot 4.7.x, **Windows and Linux Steam export presets only**.
- **Scope:** Steam init, current user id and persona name (handle suggestion, GDD Rule 16), **auth session ticket for Web API**, friends list. Overlay works without code. Nothing else (no Steam leaderboards, stats, achievements, networking or cloud) without a new ADR.
- **Isolation:** only `SteamAdapter` and a `SteamBridge` wrapper touch the extension, through `Engine.has_singleton("Steam")` / `ClassDB.class_exists(...)` checks, so non-Steam desktop, Web and tests run without it. Gameplay code never references Steam. The `.gdextension` file and binaries are excluded from the Web, mobile and itch.io presets.
- **Steam Leaderboards mirror (GDD OQ8): not at launch.** Recommendation: if wanted later, the **server** mirrors verified scores through the Steamworks partner Web API (UNVERIFIED endpoint), which needs no client code at all. The client GDExtension scope stays identity + friends.
- **Registry note:** this adds a second allowed native component next to ADR-0001's bullet-kernel fallback. The `api_decisions.language` stance is extended, not reversed (see summary registry entry).

### 7. Hosting and data region
- **Region: EU** (one region, e.g. Germany or Finland). Reason: GDPR is the strictest regime players are likely to fall under; hosting in the EU avoids international-transfer paperwork for EU players, and the data held is minimal for everyone else. Latency is irrelevant (async uploads).
- **Shape (one small deployment):** one EU VPS or EU container host running (a) a stateless HTTPS API, (b) PostgreSQL (boards, installs, claims, queue table using `SELECT … FOR UPDATE SKIP LOCKED`), (c) 1–N **verifier workers** = the game's headless Linux export per `ruleset` (current + previous, GDD Rule 8), (d) replays as `bytea` or an EU object-storage bucket. Daily encrypted backups in the same region. Expected cost at launch: low tens of EUR/month (estimate).
- **Vendor:** chosen in the server epic from EU-located providers with a GDPR Data Processing Agreement; reversible because everything is containers + PostgreSQL. **Rejected for the verifier:** serverless/edge functions (cannot run Godot binaries), BaaS leaderboards (no custom replay verification).
- **API implementation language:** server code is outside CLAUDE.md's "gameplay and UI" GDScript rule. Pick one mainstream, boring stack in the server epic (small single binary/service, OpenAPI contract checked into the repo). Workers are Godot itself.
- **Verifier worker sandbox:** container with no outbound network, read-only filesystem except a temp dir, CPU and wall-clock limits per job (`max_verify_seconds`, set from OQ4 measurements), memory limit, runs as non-root. The replay is data only (GDD Rule 24).

### 8. Privacy basics (GDPR-light)
- Lawful basis: **consent** (opt-in screen, versioned; GDD Rules 14–15). Withdrawal stops uploads; erase deletes (Rule 19).
- Data held: install id, token hash, handle, hashed Steam id, claims, results, entries, replays, friend links; hashed IP for 7 days (rate limiting). No email, no real name, no device fingerprint, no analytics, no ads.
- Retention per GDD Rule 18; deletion SLA 30 days (target: immediate).
- A plain-language privacy policy (both languages) is hosted on the own site and linked from the consent screen; it names the controller, the EU host as processor, retention and the erase path.
- **Not decided here (→ `/security-audit` + legal):** minimum age (COPPA / UK Children's Code), data export (access/portability request), Steamworks distribution terms, whether a DDoS proxy (a non-EU processor that sees IPs) is acceptable.

### Security review items (for `/security-audit`)
1. Bearer token generation, storage in `user://` (plain file; acceptable?) and server-side hashing; token rotation on erase.
2. CORS allow-list and preflight; HSTS; TLS config of the host.
3. Rate limits (GDD: 20 submits/h per install, strike rules) and per-IP limits with hashed IPs.
4. Replay parser hardening: size caps before and after decompression (decompression bomb), fuzzing the parser, no path/script fields (GDD Rule 24, security edge cases).
5. Verifier sandbox (no network, limits, non-root, image per `ruleset`, `content_hash` check).
6. Steam ticket validation server-side; Steam id HMAC secret management.
7. Handle denylist and report/hide flow abuse (mass reporting).
8. Secrets management, backups encryption, admin access (SSH keys, 2FA), dependency updates.
9. Logging without personal data; log retention.
10. Erase endpoint authorization (token only; no erase by id).
11. Legal: GDPR basis, processor DPA, privacy policy, minimum age, data export, Steamworks terms (GDD OQ2).

### Architecture Diagram

```
           (render-rate, ALWAYS)                       HTTPS (JSON / octet-stream)
OnlineHost ─_process─► adapter.poll() ◄── HttpTransport (≤2 HTTPRequest) ───────────► EU host
   │                         ▲                                                          ├─ API (stateless)
OnlineService (RefCounted)   │                                                          ├─ PostgreSQL (boards, queue)
  ├ UploadQueue  user://online_queue.json + replays/*.mjr                               ├─ Verifier workers
  ├ BoardCache   user://online_cache.json                                               │   (Godot headless, per ruleset,
  └ LeaderboardAdapter ──┬─ HttpAdapter (Web, itch, PC only)                            │    no network, CPU/time caps)
                         ├─ SteamAdapter = HttpAdapter + SteamBridge ─► GodotSteam      └─ Steam Web API (ticket check)
                         ├─ NullAdapter  (no consent / offline / no service /                (GDExtension, Win/Linux Steam only)
                         │                 Switch and mobile: no adapter at launch)
                         └─ FakeAdapter  (tests)
GameLoop (60 Hz) ── never calls online code; ReplayRecorder is ADR-0003's
```

### Key Interfaces

```gdscript
class_name LeaderboardAdapter extends RefCounted   # GDD Rule 5; async via poll()
func identity() -> Dictionary                     # {provider, id_token, display_hint}
func friends() -> PackedStringArray
func fetch(board_key: String, scope: int, offset: int, count: int) -> int
func fetch_around(board_key: String, scope: int) -> int
func submit(claim: Dictionary, replay_bytes: PackedByteArray) -> int
func status(submission_id: String) -> int
func delete_my_data() -> int
func poll() -> Array[OnlineEvent]

class_name HttpTransport extends Node               # the only node; owns HTTPRequest pool
func send(method: int, path: String, headers: PackedStringArray, body: PackedByteArray) -> int
```

## Alternatives Considered

### Alternative A (chosen): Custom EU verifier authoritative + adapters; GodotSteam GDExtension for identity/friends only
Described above.

### Alternative B: Steam Leaderboards only
- **Pros**: Free hosting, no server, friends built in.
- **Cons**: No replay verification, int32 + small detail only, Steam/PC only, nothing on Web or phones, client-side GDExtension calls for everything.
- **Rejection Reason**: Fails Every Hit Counts (unverified scores) and the Web-first platform plan (GDD Rule 4).

### Alternative C: Third-party game backend (BaaS leaderboards)
- **Pros**: Hosted boards, auth, dashboards.
- **Cons**: Replay re-simulation still needs our own Godot workers; extra vendor, data processor (often non-EU), SDKs that may need C#/native code; lock-in.
- **Rejection Reason**: Does not remove the hard part and adds a processor.

### Alternative D: No Steam GDExtension (install id + friend codes on Steam too)
- **Pros**: Keeps "GDScript only" absolute; one adapter everywhere.
- **Cons**: Steam players get friend codes instead of their friends list and a second identity; worse Steam fit.
- **Rejection Reason**: Kept as the **fallback** if V4 fails (no GodotSteam build for 4.7). The interface makes the switch a config change.

### Alternative E: GodotSteam module build (custom editor/templates)
- **Pros**: Full Steam API, no extension loading.
- **Cons**: Custom engine builds for every patch; diverges from the official templates the project depends on.
- **Rejection Reason**: Maintenance cost for a solo developer.

### Alternative F: US or multi-region hosting
- **Pros**: Cheaper/more vendor choice; lower latency for some.
- **Cons**: International-transfer obligations for EU players; latency does not matter for async uploads.
- **Rejection Reason**: EU is the simplest compliant default.

## Consequences

### Positive
- One trust model and one board set on every platform; consoles later add an adapter only.
- Online code is fully testable offline (Fake/Null adapters); the tick never waits on the network.
- Minimal personal data and EU hosting keep the legal footprint small.

### Negative
- The project now operates a server (cost, uptime, patching, moderation).
- A native component ships in Steam builds (a second exception to GDScript-only).
- Web depends on CORS and browser storage behaviour in iframes.

### Risks
| Risk | Mitigation |
|---|---|
| Cross-platform determinism fails (ADR-0003 spike) | GDD Rule 23 fallback: same-platform-class verification + `UNVERIFIED` tab; the transport is unchanged |
| itch.io iframe origin / storage blocks requests | V2 on itch.io; fallback: host the Web build on the own site for online features; `NullAdapter` notice |
| No GodotSteam build for 4.7.x | Alternative D (friend codes on Steam) until a build exists |
| Server cost grows with replays | `verify_top_n` + audit sampling (GDD Rule 24.3); replay retention 7 days off-board |
| Worker exploited via crafted replay | Sandbox + parser caps + fuzzing (security items 4–5) |
| Desktop TLS CA bundle outdated in old builds | Mainstream CA; no pinning; `UPDATE_REQUIRED` code for very old builds |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| online-leaderboards-boss-rush.md | Rule 4 (option C), Rule 5 (adapter interface), Rule 6 (adapters per platform) | Decisions 1–2 |
| online-leaderboards-boss-rush.md | Rule 6 / OQ8: Steam needs a GDExtension "→ ADR"; mirror worth it? | Decision 6: scoped exception; mirror deferred to server-side |
| online-leaderboards-boss-rush.md | Rule 7 / OQ2: hosting vendor and region → ADR and `/security-audit` | Decision 7 (EU), 8, security items |
| online-leaderboards-boss-rush.md | Rules 14–19 (consent, minimisation, retention, erase) | Decision 3 auth, Decision 8 |
| online-leaderboards-boss-rush.md | Rule 29 (never block), Rule 32 (no writes during a stage), OQ13 (TLS), AC-49 (CORS/iframe), AC-50 (Steam) | Decisions 2, 4, 5; V1–V4 |
| save-settings-high-scores.md | Local boards stay authoritative locally; queue files separate from `scores.json` | `OnlineService` writes only its own files |

## Performance Implications
- **CPU**: `poll()` once per rendered frame (microseconds); no work during Stage/Tally on Web.
- **Memory**: Queue ≤ 10 claims × ≤ 256 KB replays (GDD F3) ≈ 2.5 MB worst case on disk; cache small.
- **Load Time**: Steam init on Steam builds only.
- **Network**: One upload ≤ 256 KB per ranked run; board pages a few KB.

## Migration Plan
1. Client: `NullAdapter`, `FakeAdapter`, `OnlineService`, queue/cache with unit tests (no server needed).
2. Transport spike (V1–V3) against a throwaway HTTPS echo endpoint in the EU.
3. After ADR-0003's spike and `/security-audit`: server epic (API, DB, worker image), then `HttpAdapter`.
4. Steam: add the GodotSteam extension to a `windows-steam` / `linux-steam` preset only; `SteamAdapter` (V4).
5. Update `CLAUDE.md` Technology Stack and `.claude/docs/technical-preferences.md`: "C++ GDExtension: bullet-kernel fallback (ADR-0001) and GodotSteam for Steam identity/friends (ADR-0007) only."

## Validation Criteria
- **V1** — Desktop release build: HTTPS GET/POST (binary 256 KB body) to the EU test host succeeds with the bundled CAs; a self-signed host is refused.
- **V2** — Web release build on REF-WEB from (a) the own site and (b) an itch.io page: preflighted `POST` with `Authorization` and binary body succeeds; blocked storage → `NullAdapter` notice; no request while in `Stage`. Records the exact itch.io origin for the allow-list (Online AC-49).
- **V3** — A 10 s timeout and an offline network both leave play and menus responsive (no frame > 20 ms caused by online code on REF-WEB).
- **V4** — Steam build: GodotSteam for 4.7.x loads; ticket → server validation → token; friends list read; a desktop build without the extension starts and uses `HttpAdapter` (Online AC-50).
- **V5** — `/security-audit` report closes items 1–11 or lists accepted risks.

## Related Decisions
- ADR-0001 (GDScript only — amended by Decision 6), ADR-0003 (replay format, determinism, verification contract), ADR-0004 (OnlineHost placement).
- Design: `design/gdd/online-leaderboards-boss-rush.md`, `save-settings-high-scores.md`, `accessibility-options.md` (assisted runs never upload).

> Engine review: not yet run — `godot-specialist` to confirm HTTPRequest Web/TLS behaviour and GodotSteam 4.7 availability. Security review: `/security-audit` required before Accepted. TD-ADR skipped — Lean mode.
