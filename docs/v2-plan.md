# Moves v2 — Personal Task Cockpit

**Status:** REFINED (Opus plan → Fable critique → Opus refine). Awaiting one
gating decision from Carlos (topology, §3) before Phase 2+ detail locks.
**Owner:** Carlos · **Date:** 2026-08-06

## 1. Vision

Moves becomes Carlos's **single personal task surface** — a cockpit that
federates tasks which *live* in their source systems while giving one calm place
to see, capture, assign, and delegate everything.

- Work tasks live in **Olympus** (Coba work system, on Fly.io) and mirror into Moves.
- Agent tasks live in **Darwin** (the Hermes agent system, local at `~/.hermes`).
- Personal/strategic moves live natively in **Moves**.
- **Metis** (durable-memory brain) is the shared substrate; Moves notes sync to it.

## 2. Capabilities requested (scope source of truth)

1. Connect "my work" so self-assigned work tasks appear in Moves (Olympus → Moves).
2. Assign tasks from the app / PWA on the phone.
3. Agents can add tasks **and subtasks**, and generate **prompts saved as notes**.
4. **Delegate** a move to an agent (e.g. Darwin); the agent posts back **done** or **problem**.
5. **Notes → Metis** sync: writing a note lands it in Metis; searching notes hits Metis.
6. Olympus can push "today's tasks" so they ride along on the phone.
7. Darwin can create tasks, read notes, and reach Metis (it already has Metis).

The gap across every one of these systems is a **unifying personal task surface** —
that is what Moves v2 provides.

## 3. GATING DECISION — topology (must be chosen first)

*Fable B1: the deployment decision silently determines Phases 5–7, the auth
transport, AND the Metis-sync shape — it is not a footnote.* The Metis CLI and the
Hermes gateway both live on the **devbox** (`localhost`); the phone and Olympus (Fly)
need Moves reachable from outside. Those pull in opposite directions:

- **(A) Devbox-hosted + tunnel** (Tailscale/Cloudflare): Metis and Hermes are
  local → direct CLI sync and direct delegation handoff. Phone/Olympus reach Moves
  through the tunnel. Weakest availability (laptop must be up). Simplest integration.
- **(B) Fly-hosted** (next to Olympus): always reachable for phone/Olympus, but
  Metis/Hermes are now remote → Metis sync becomes a **devbox-side relay** (a local
  agent pulls unsynced notes from the Moves API and writes them to Metis), and Darwin
  must **poll** the API (no inbound webhook to a local gateway). Best availability,
  more moving parts.

Everything below is written to be **topology-agnostic where possible** and flags
where the choice changes the design. **No Phase 2+ code starts until this is picked.**

## 4. Architecture — one hub, thin clients

**Principle:** Moves exposes ONE token-authed HTTP JSON API (`/api/v1`). Every other
surface is a thin client of that one contract; no business logic is duplicated (DRY).

```
   Olympus (Fly cron, curl) ─┐
   Phone / PWA (session) ─────┤
   Darwin / Hermes (plugin) ──┤─▶  Moves  (Rails)  ─▶  models + services
   Claude / agents (CLI) ─────┤     /api/v1  + web       (EV, delegation)
   bin/moves CLI ─────────────┘         │
                                        └─▶ MetisSync (topology-appropriate)
```

- **Client set (Fable S3 — cut the false economy): API + one thin `bin/moves` CLI.**
  Olympus is a curl in cron; the Hermes `moves` plugin is itself a Python API client;
  Claude/agents can drive the CLI over Bash. **MCP is deferred** until a specific
  agent host demonstrably needs native tools — it adds a surface with no new capability today.

## 5. Auth — whole app, not just the API (Fable B2)

The phone requirement exposes the **web UI**, which today has **no login** and a
`/settings` page holding a **plaintext `openai_api_key`** in SQLite. So:

- **Browser + PWA → session auth.** Single-user password via Rails 8's built-in auth
  (`has_secure_password`). Do NOT put bearer tokens in a service worker.
- **API clients → scoped bearer tokens**, stored **hashed** (SHA-256), compared with
  `ActiveSupport::SecurityUtils.secure_compare`, with **scopes**, `revoked_at`, and a
  `bin/rails moves:token:{mint,revoke}` task. Scopes: `olympus` = create/update
  *mirrored* moves only; `darwin` = read own queue + post callback only.
- Encrypt `openai_api_key` at rest (Rails `encrypts`). Rate-limit the API
  (`rack-attack`) if internet-exposed. Log token **name** (never the token) per request.
- **Transport:** tokens ride only over TLS (Fly) or the tunnel — never plain HTTP.

## 6. Data model changes (revised per Fable B3/B4, S1, S7)

- **Note** → first-class `notes` table: `uuid`, `move_id?`, `body`, `kind`
  (`note`|`prompt`), `source` (`carlos`|`agent`|`olympus`|`darwin`), `metis_slug`,
  `metis_synced_at`, timestamps. Project is derived (`move.campaign&.project`), **not
  stored**, to avoid a contradictory `project_id` (S7).
  - Migration is **one shot** (no dual-read — single-writer SQLite, S1): create table,
    backfill one `Note` per non-blank `moves.notes`, repoint the **three** existing
    writers (`move_params`, `parse_submit`, `apply_ai_suggestions`), and teach
    `BackupExporter/Importer` the new table (else backups silently drop notes).
- **Subtasks → `checklist_items` table** (`move_id`, `title`, `done`, `position`,
  `uuid`). **Not** `parent_move_id` (Fable B3: that taxes FocusClassifier,
  RecommendationEngine, StalenessDetector, campaign metrics, backup ordering, and
  every existing move query). Promote an item to a real Move later only if it earns it.
- **Federation fields on `moves`**: `source`, `external_id`, `external_url` +
  **partial unique index** on `[source, external_id] WHERE both NOT NULL`. Writes use
  **find-or-create + save** (NOT `upsert`/`insert_all`, which skip `ensure_uuid`
  callbacks and scoring), rescuing `RecordNotUnique`. **Field ownership:** source
  system owns identity fields (title/description/due); Moves owns scoring/stage/
  signals/notes. **Reconciliation:** a sweep auto-archives mirrored moves not
  re-pushed in N days (else zombie inbox items accumulate).
- **Delegation fields on `moves`**: `assignee`, `delegation_state`
  (`none`|`delegated`|`accepted`|`in_progress`|`done`|`blocked`|`stalled`),
  `delegation_id` (nonce issued at delegate-time), `delegation_result`,
  `delegated_at`, `reported_at`.

## 7. `/api/v1` surface

- `moves` (index/show/create/update) + `checklist_items`; `notes` CRUD + `GET
  /notes/search` (Metis-backed with local fallback).
- `POST /moves/:id/delegate` → issues `delegation_id`, sets `delegated`.
- `POST /moves/:id/delegation/callback` → agent reports `done`/`blocked` + result;
  **must echo the current `delegation_id`** (rejects stale/duplicate late callbacks,
  Fable B5); authorized only for `assignee==darwin` moves in an in-flight state.
- `GET /moves?assignee=darwin&state=delegated` → poll queue; pickup uses an **atomic
  claim** (`UPDATE ... WHERE delegation_state='delegated'`, check rows affected) so two
  Hermes workers can't grab the same move.
- `GET /today` → defined as: FocusClassifier "best moves now" ∪ due-today ∪ pending
  delegations (Fable N2). Contract: pagination + error envelope + created/updated flag
  on federation writes.
- **Timeout sweep** (Solid Queue recurring): `delegated_at < 24h && no report →
  stalled`, surfaced on Focus, so delegation never silently eats a task.

## 8. Metis notes sync (revised per Fable B6)

- **Primitive:** mutable note bodies use **`put_page` under a per-note slug**
  (`projects/moves-notes/<uuid>`) so re-put **replaces** content — NOT `put_fact`
  (whose cosine-0.90 dedup silently drops edits and can never be corrected).
  *Verify replace semantics against `metis guide` before Phase 3 code.*
- **Sync `kind: note` only** — never `kind: prompt` (ephemeral agent artifacts must
  not pollute durable memory).
- **Job carries note ID, not body**; reads current body at run time; **skips if
  `metis_synced_at >= note.updated_at`** (so a reordered Solid Queue retry can't
  overwrite a newer edit); debounced against edit storms.
- **Deletes:** Metis is append-only for notes — document that `metis_synced_at`
  means "last pushed," not "mirror." Deleting in Moves does not delete in Metis.
- **Search:** `GET /notes/search` proxies `metis search` with a ~3s timeout and
  **first-class fallback to local `LIKE`** when Metis is down; merges with local.
- **Sync shape depends on topology (§3):** local → direct `MetisClient` (CLI at
  `$METIS_CLI`, never a hardcoded repo path); Fly → devbox-side **relay** pulls
  unsynced notes from the API and writes them.
- **Inbound (Metis → Moves) is deferred** and, when built, must drop anything whose
  origin marker/`metis_slug` shows it came from Moves (echo-loop guard).

## 9. External adapters

- **Olympus (Fly):** daily cron `curl`s today's tasks → `/api/v1/moves`
  (`source=olympus`, scoped token, find-or-create, field-ownership rules,
  reconciliation sweep per §6).
- **Darwin (Hermes):** a Hermes **`moves` plugin** mirroring
  `~/.hermes/plugins/metis/client.py`. Creates tasks/checklist-items, writes
  prompt-notes, reads notes; for delegated moves it **polls** the queue, atomically
  claims, executes, and POSTs the callback with the echoed `delegation_id`.
  **Polling only** — the webhook option is dropped (dead in Fly topology, needless
  attack surface locally).

## 10. Electron (Fable S5 — was unaddressed)

Electron bundles its **own local Rails + SQLite** → a second, divergent DB once Moves
is hosted. Decision needed with topology: **thin shell** pointing at the hosted URL,
**deprecate** in favor of the PWA, or keep local-first and accept sync. Default
recommendation: **deprecate Electron in favor of the PWA** once topology is chosen.

## 11. Phasing (re-sequenced per Fable — dependencies run topology → auth → API → adapters)

- **Phase 0 — Unblock the repo.** Ruby 3.2.9 toolchain + bundler, `bin/rails test`
  green, triage the ~10 Dependabot PRs. *Nothing runs until this is done.*
- **Phase 1 — Topology (§3) + minimal auth (§5).** Pick A or B; add session auth to the
  whole web app + the scoped token model; encrypt the OpenAI key. Small, de-risking PR.
- **Phase 2 — Smallest valuable slice:** token-authed `/api/v1` moves
  (index/show/create/update) + `GET /today` + a ~50-line `bin/moves` CLI. Delivers
  "agents & cron can put tasks into the cockpit" on day one. No subtasks/federation/
  delegation yet.
- **Phase 3 — Notes:** `notes` table + one-shot backfill + repoint 3 writers + backup
  coverage + notes API, then Metis outbound sync (§8) in the topology-appropriate shape.
- **Phase 4 — Checklist items + agent prompt-notes.** Cheap, contained.
- **Phase 5 — Delegation loop:** fields + `delegation_id` + atomic claim + scoped darwin
  token + timeout sweep + Hermes `moves` plugin (polling).
- **Phase 6 — Olympus adapter:** partial unique index + find-or-create + field ownership
  + zombie reconciliation.
- **Phase 7 — PWA:** manifest + service worker (offline shell + queued capture) +
  mobile capture; push later. (MCP server only if/when an agent host needs it.)

Each phase = its own branch + PR + Codex adversarial review. Phase 1 is split into
small PRs, not one mega-PR (Fable S4).

## 12. Non-negotiables

- Public repo → **no secrets** in code/tests/fixtures/config; all paths via ENV
  (`METIS_CLI`, `HERMES_GATEWAY_URL`), values only on the devbox; fixtures use
  obviously-fake tokens (Fable N3).
- SQLite: WAL + `busy_timeout`, Solid Queue on its own DB, batch imports in one
  transaction; add offsite backup (Litestream or scheduled export) since this DB now
  holds the only copy of federated state (Fable S6).
- Follow the army-of-agents pipeline (`CLAUDE.md`); persist durable state to Metis
  (`projects/moves-task-manager`).

## 13. Deferred hardening backlog

Accepted, deliberate deferrals from shipped phases — safe for a single-user app
today, but **required before internet/tunnel exposure or if the threat model
changes**. Tracked here (not just in commit messages) so they aren't lost.

**Before the API is exposed over the tunnel (from Phase 2):**
- Rate limiting (`rack-attack`), especially on `/api/v1/today` and repeated 401s.
- Request **Host Authorization** (`config.hosts`) — needs the real tunnel hostname.
- Reject non-JSON content type with `415` on API writes.
- Set `MOVES_TIME_ZONE` on the server so `/api/v1/today`'s day boundary is correct.

**Metis notes sync (Phase 3):**
- Auto-retry a failed Metis put (currently re-syncs on the note's next edit).
- Deletion/tombstone story (Metis is append-only; deleted notes persist there).
- A test that a hung metis CLI is actually killed by the `timeout` wrapper.

**Checklist items (Phase 4):**
- A `(move_id, position)` unique index / row-lock for concurrent-tab position races.
- Pagination / lazy-load for very long checklists (and the notes list).
