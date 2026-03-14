# Moves

A minimalist task manager with hidden decision-intelligence. Moves helps you capture tasks quickly, score them with expected-value logic, and surface the best actions to take right now.

![Ruby](https://img.shields.io/badge/Ruby-3.2+-CC342D?logo=ruby&logoColor=white)
![Rails](https://img.shields.io/badge/Rails-8.1-D30001?logo=rubyonrails&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?logo=sqlite&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)

## What It Does

Moves treats every task as a "move" — something with a probability of success, an effort cost, and a payoff. Behind a clean, calm UI, an EV (expected value) engine continuously scores and ranks your work so you always know what deserves attention.

**Key concepts:**

- **Moves** — individual tasks scored by probability, effort, and payoff
- **Campaigns** — groups of related moves toward a shared objective
- **Projects** — color-coded filter lenses with cadence-based health tracking
- **Signals** — lightweight check-ins that update a move's probability over time
- **Focus page** — auto-curated view of your best moves, strategic bets, and stale items

## Features

- **Smart capture** — type a short phrase for instant capture, paste a long block for AI-powered field extraction
- **4-step move wizard** — guided creation: title, probability/effort, payoff, confirm
- **EV scoring engine** — `(payoff x probability) / effort` with staleness decay and signal adjustments
- **Recommendation labels** — Move now, Strong position, Gone quiet, Low priority, Let it go, Re-examine
- **Monday brief** — weekly stats card with top move, most neglected project, and pipeline overview
- **Command palette** — `Cmd+K` for instant search and quick capture from anywhere
- **Project filtering** — sidebar switcher with color dots; click to scope, click again to clear
- **Signal logging** — record positive/negative/neutral signals that automatically adjust probability
- **AI suggestions** — optional OpenAI integration for move classification, signal summaries, and probability hints
- **Text-to-Move** — paste unstructured text or voice transcription, AI extracts structured fields
- **Backup/restore** — full JSON export/import with UUID-based conflict resolution
- **10-step product tour** — onboarding walkthrough with spotlight highlights, re-runnable from Settings
- **Electron desktop app** — macOS wrapper that bundles Rails + SQLite locally

## Design

Japanese-Swiss aesthetic — warm off-white backgrounds, sage green accents, Inter typeface. Intentionally calm. The intelligence layer stays hidden until you need it.

| Token | Value |
|-------|-------|
| Background | `#F5F4F0` |
| Surface | `#FFFFFF` |
| Ink | `#18181A` |
| Accent (sage) | `#1E5C42` |
| Amber | `#8B6020` |
| Font | Inter, system-ui |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Ruby on Rails 8.1 |
| Frontend | Hotwire (Turbo + Stimulus) |
| JS bundling | Importmap (no build step) |
| Database | SQLite |
| Asset pipeline | Propshaft |
| Background jobs | Solid Queue |
| Cache | Solid Cache |
| WebSocket | Solid Cable |
| AI (optional) | OpenAI API (gpt-4.1-mini default) |
| Desktop | Electron 36 |

## Getting Started

### Prerequisites

- Ruby 3.2+
- Bundler
- Node.js 18+ (for Electron desktop only)

### Web App

```bash
# Install dependencies
bundle install

# Set up database
bin/rails db:setup

# Start the server
bin/dev
```

Open [http://127.0.0.1:3000](http://127.0.0.1:3000)

### Desktop App (Electron)

```bash
# Install Electron dependencies
npm install

# Run desktop (starts Rails internally)
npm run desktop:dev

# Build macOS DMG
npm run desktop:build:dmg
```

### AI Features (Optional)

Moves works fully offline. To enable AI suggestions, signal summaries, and text-to-move parsing:

1. Set your API key:
   ```bash
   export OPENAI_API_KEY=your_key_here
   ```
2. Or configure it in-app: **Settings** → enter your OpenAI API key → enable AI

The key is stored locally in your SQLite database and never transmitted anywhere except OpenAI's API.

## Architecture

```
app/
├── controllers/        # 12 controllers (Focus, Inbox, Moves, Campaigns, etc.)
├── models/             # Move, Campaign, Project, MoveSignal, AppPreference
├── services/           # EV calculator, recommendation engine, focus classifier,
│   │                   # staleness detector, signal impact, weekly brief, AI provider
│   └── ai/providers/   # OpenAI integration
├── javascript/
│   └── controllers/    # Stimulus: wizard, command palette, smart capture,
│                       # tour, project modal, context menu, disclosure
├── helpers/            # Display label mapping, badge classes
└── views/              # ERB templates

electron/               # Desktop wrapper (main.js, preload.js)
```

### How EV Scoring Works

1. **Base EV** = `(payoff_normalized × probability) / effort_minutes`
2. **Signals** adjust probability — positive signals increase it, negative decrease it
3. **Staleness** decays scores — 10+ days without signals triggers "Gone quiet", 21+ days triggers "Re-examine"
4. **Recommendation engine** combines EV, probability, effort, and staleness into a human label
5. **Focus classifier** buckets moves into: Best moves now, Strategic bets, Needs a call

### Key Services

| Service | Purpose |
|---------|---------|
| `EvCalculator` | Computes expected value from payoff, probability, effort |
| `RecommendationEngine` | Maps EV + signals into action labels |
| `FocusClassifier` | Waterfall sort into focus buckets |
| `SignalImpactEngine` | Adjusts probability based on signal direction/magnitude |
| `StalenessDetector` | Flags moves that have gone quiet |
| `WeeklyBriefService` | Monday morning stats and insights |
| `AiSuggestionProvider` | Facades OpenAI for suggestions, summaries, parsing |
| `BackupExporter/Importer` | Full JSON backup with UUID conflict resolution |

## Testing

```bash
bin/rails test
```

## Backup & Restore

From the **Settings** page:
- **Export** — downloads a JSON file with all moves, campaigns, projects, and signals
- **Import** — uploads a JSON backup; uses UUID matching to avoid duplicates

## Project Structure

| Route | Page | Purpose |
|-------|------|---------|
| `/focus` | Focus | Default landing — best moves, weekly brief |
| `/inbox` | Inbox | Uncategorized moves awaiting triage |
| `/moves` | All Moves | Full list with search and filters |
| `/moves/:id` | Move Detail | Signals, AI tools, state transitions |
| `/campaigns` | Campaigns | Campaign cards with progress stats |
| `/archive` | Archive | Completed and archived moves |
| `/settings` | Settings | AI config, tour restart, backup/restore |

## License

MIT
