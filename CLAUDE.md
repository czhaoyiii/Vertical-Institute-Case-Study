# CLAUDE.md

## Stack rules

- Ruby 3.4, Rails 8.1, SQLite 3 — never suggest PostgreSQL-specific syntax
- No `jsonb` columns — use `text` + `serialize :col, coder: JSON` in the model
- No `NULLS FIRST` in ORDER BY — rewrite as `ORDER BY (col IS NOT NULL), col ASC`
- No `ILIKE` — SQLite `LIKE` is already case-insensitive for ASCII
- No `default: -> { "now()" }` — omit and rely on Rails timestamps, or use `CURRENT_TIMESTAMP`
- Asset pipeline is Propshaft + Importmap — no Webpack, no Node build step
- Tailwind CSS compiled via `tailwindcss-rails` gem (`bin/rails tailwindcss:build` / `tailwindcss:watch`)
- Tailwind input: `app/assets/tailwind/application.css` → output: `app/assets/builds/tailwind.css`
- Layout links stylesheet with `stylesheet_link_tag "tailwind"`

## Styling rules

- **Zero `style=""` attributes** — the only allowed exception is dynamic percentage widths (`style="width: X%"`) on progress bars where Tailwind cannot generate the value at runtime
- **One CSS file only** — `app/assets/tailwind/application.css` (`@import "tailwindcss"` + `@theme` tokens). No other `.css` files may contain rules
- All spacing, colour, layout, and typography via Tailwind utility classes
- shadcn design tokens live in the `@theme {}` block — use them as `bg-background`, `text-foreground`, `text-primary`, etc.
- Colour palette: slate/zinc neutrals, indigo brand primary, rose danger/high-risk, amber warning/medium-risk, emerald success/low-risk

## Rails conventions

- Partials get explicit `locals:` — never rely on instance variables inside a partial
- Helpers for any class name or label derived from data — see `RiskHelper`
- Service objects for complex logic — `RiskAssessment` and `AiSummaryService` are plain Ruby classes, not model methods
- Named scopes everywhere — `by_risk`, `at_risk`, `active` — no raw `.where` chains in controllers
- Always `includes(...)` on enrollment queries to prevent N+1
- Computed metrics (progress %, attendance) are derived from the `activities` table — never stored as columns
- Turbo Frames for async loads (AI panel), Turbo Streams for mutations (AI generate, email regenerate)
- Stimulus `data-action` for all JS behaviour — no inline `onclick`

## Controller rules

- `dom_id` is a view helper — include `ActionView::RecordIdentifier` in any controller that needs it
- HTTP Basic Auth via `authenticate_or_request_with_http_basic` in `ApplicationController`

## Model rules

- `Activity#metadata` — `serialize :metadata, coder: JSON` (text column)
- `AiSummary#next_steps` — `serialize :next_steps, coder: JSON` (text column, stores array)
- `Enrollment` computed metrics: always query `activities` directly, never cache counts as columns

## AI service rules

- `AiSummaryService` uses `gpt-4o-mini`, `response_format: { type: "json_object" }`, temperature 0.4
- Always fall back to deterministic mock output when `OPENAI_API_KEY` is absent or call fails
- `OpenAIClient.configured?` checks before any API call

## What NOT to do

- No `style=""` except dynamic progress widths
- No raw SQL strings without `Arel.sql()` wrapper
- No storing attendance rate, progress %, or lesson counts as database columns
- No inline JavaScript — use Stimulus controllers
- No duplicate long Tailwind class strings — extract to a partial or helper
