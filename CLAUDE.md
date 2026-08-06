# CLAUDE.md — Moves

Guidance for Claude Code (and every agent) working in this repo. Read this first,
then recall from Metis (see **Memory**) before doing anything non-trivial.

## What this project is

**Moves** — a minimalist task manager with a hidden decision-intelligence layer.
Every task is a "move" scored by expected value: `(payoff × probability) / effort`,
with staleness decay and signal-based adjustments. Rails 8.1 + Hotwire (Turbo/
Stimulus), Importmap (no build step), SQLite, Solid Queue/Cache/Cable, optional
OpenAI integration, and an Electron desktop wrapper.

Full domain model, routes, services, and design tokens live in `README.md` —
read it rather than re-deriving. Key services are in `app/services/`
(`EvCalculator`, `RecommendationEngine`, `FocusClassifier`, `SignalImpactEngine`,
`StalenessDetector`, `WeeklyBriefService`, AI providers, backup export/import).

## How we work here — the army of agents

We do NOT freelance. Every non-trivial change flows through this pipeline:

1. **Plan (Opus).** Opus writes the plan — scope, files touched, task breakdown.
2. **Critique (Fable).** Fable adversarially critiques the plan: gaps, risks,
   simpler paths, wrong assumptions.
3. **Refine (Opus).** Opus folds the critique back into a tightened plan.
4. **Delegate (→ Sonnet / Haiku).** Opus splits the plan into self-contained
   tasks and dispatches them to Sonnet and Haiku sub-agents to implement.
5. **Review for DRY (Opus).** When sub-agents return, Opus reviews the combined
   work against **DRY** and the rest of our engineering principles — no
   duplication, right altitude, reuse over reinvention.
6. **Commit often.** Small, coherent commits as work lands — not one mega-commit.
7. **Open PR(s).** Bundle the work into reviewable PRs.
8. **Adversarial review (Codex).** Codex runs an adversarial review of each PR.
9. **Rework loop.** Findings are dispatched back through steps 4–8 until the PR
   is clean. Then it merges.

Opus is the orchestrator and the only one that plans, delegates, and does the
final DRY pass. When in doubt about where you are in the pipeline, say so and
re-anchor rather than skipping a stage.

## Memory — Metis is our brain

**Metis is the durable memory system** (Postgres-backed server on
`http://localhost:8099`). It is the single source of truth for long-lived
context — not chat, not agent-local memory. Carlos wants every agent to dogfood
it. Recall from it *before* answering; write durable learnings *into* it.

**CLI** (not on PATH — use the full path):

```
/home/camego/Documents/coba-twin/repos/metis/.venv/bin/metis
```

Run `metis guide` for the full contract and `metis <op> --help` for params.
**Interact only through the CLI** — never touch Postgres, run SQL, or roll your
own dedup/embedding. The server owns all of that.

### Slugs — where things go

| Slug | What lives there |
|------|------------------|
| `projects/moves-task-manager` | Everything about THIS project: product plan, architecture decisions, in-flight state, gotchas, session handoffs |
| `topics/software-development` | General engineering insights & best practices not specific to Moves (reuse across projects) |
| `people/carlos` | About Carlos — working style, preferences, standing instructions |

Reuse the most specific existing slug; don't invent generic buckets.

### Recall (read) — before you act

```
metis search --query "<question>" --limit 5
metis recall_facts --entity-slug projects/moves-task-manager --limit 15
metis get_page --slug projects/moves-task-manager
```

### Remember (write) — durable facts only, one clean sentence

```
metis put_fact --entity-slug projects/moves-task-manager --kind <event|commitment|preference|fact> --fact - <<'FACT'
<the fact, in the language it was actually said>
FACT
```

- `event` = a dated thing that happened · `commitment` = a promise/todo ·
  `preference` = a durable liking/policy · `fact` = a durable state.
- Always pass the fact on STDIN via `--fact -` and a quoted heredoc — never a
  shell-quoted `--fact` argument (quotes/apostrophes/newlines break it).
- Dedup is automatic (cosine ≥ 0.90 per entity) — re-writing the same fact is a
  safe no-op. Don't pre-check for duplicates.
- To fix a wrong fact, write the corrected fact — the server supersedes it.
  Never hand-delete.
- Store the evolving **product plan** and **session handoff** as a page:
  `metis put_page --slug projects/moves-task-manager --type project --title "Moves" --content -`.

### Compaction protocol (hooks handle the reminders)

Context gets summarized (compacted) periodically; hooks nudge us around it.

- **Before compaction:** persist everything durable that isn't already in Metis —
  what we learned, what we uncovered about how the code/product works, the
  current plan, and where we are in the pipeline. Update the handoff page.
- **After compaction / new session:** recall from Metis first
  (`projects/moves-task-manager` + `people/carlos`) to reload state before
  continuing. Treat Metis, not the summary, as the source of truth.

Also store, as you go: project-specific insights → `projects/moves-task-manager`;
general engineering insights → `topics/software-development`; things about
Carlos → `people/carlos`.

## Security — this is a PUBLIC repo

`github.com/Chosen9115/moves` is public. Therefore:

- **Never commit secrets** — no API keys, tokens, `.env` files, Metis tokens,
  credentials, or private URLs. The OpenAI key is user-supplied at runtime and
  stored locally in SQLite; it must never enter the repo.
- Never paste secrets into code, comments, tests, fixtures, or commit messages.
- Metis server tokens and local config stay on the devbox, never in the repo.

## Local environment notes

- `.ruby-version` pins **Ruby 3.2.9**; this devbox currently has system Ruby
  3.4.8 and **no `bundle` on PATH**. Toolchain must be set up (a version manager
  installing 3.2.9 matches CI) before `bin/dev` or `bin/rails test` will run.
- Node 26 is present (Electron is fine).
- Tests: `bin/rails test`. Lint: RuboCop (`.rubocop.yml`). CI:
  `.github/workflows/ci.yml`. Security scan: Brakeman.
- ~10 open Dependabot branches await review/merge.
