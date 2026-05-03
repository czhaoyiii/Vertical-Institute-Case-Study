# At-Risk Student Follow-Up Tool

An internal staff dashboard for Vertical Institute to identify at-risk students, understand why they were flagged, and take action with AI-generated follow-up emails.

Built with Ruby on Rails 8.1, SQLite, Tailwind CSS, and OpenAI.

---

## Requirements

- Ruby 3.4+
- Bundler (`gem install bundler`)
- foreman (`gem install foreman`) — installed automatically by setup

---

## Setup

### 1. Clone and install dependencies

```bash
git clone <repo-url>
cd vi-case-study-project
bundle install
```

### 2. Configure environment variables

```bash
cp .env.example .env
```

Open `.env` and fill in your values:

```
ADMIN_USER=admin
ADMIN_PASS=vertical
OPENAI_API_KEY=sk-...    # optional — project still works offline without it
```

`ADMIN_USER` and `ADMIN_PASS` are the HTTP Basic Auth credentials for the staff portal. The defaults (`admin` / `vertical`) work out of the box if you leave them blank.

### 3. Set up the database

```bash
bin/rails db:create db:migrate db:seed
```

Seed data creates:
- 3 courses (Data Analytics Bootcamp, Generative AI Fundamentals, Full-Stack Web Development)
- 30 students across realistic engagement archetypes (on-track, slightly behind, lagging, disengaging, silent)
- ~40 enrollments and ~1,200 activity events
- Risk scores computed for every enrollment

### 4. Start the development server

```bash
bin/dev
```

This runs Puma and the Tailwind CSS watcher in parallel via foreman. The app will be available at [http://localhost:3000](http://localhost:3000).

Log in with `admin` / `vertical` (or whatever you set in `.env`).

---

## Features

### Dashboard
- Live table of all active enrollments sorted by risk severity
- Filter by risk level (High / Medium / Low), course, and free-text search
- Sort by risk, name, or last activity date
- Stat cards: total students, at-risk count, high-priority follow-ups, average progress

### Student detail page
- Risk Analysis panel: course progress bar, days inactive, attendance rate, flagged risk factors with severity labels
- AI Insights panel (loads asynchronously): situation summary, immediate action, reasoning narrative, recommended action, suggested next steps
- Follow-Up Draft panel: AI-generated email subject and body, one-click copy, mailto link to open in your email client, regenerate button

### Courses
- Course index with stacked risk distribution bar per course
- Course detail with enrolled students sorted by risk

### AI feature
Uses `gpt-4o-mini` with a structured JSON prompt to generate:
- A staff-facing situation summary
- An immediate action call-out
- Reasoning narrative explaining why the student is at risk
- A recommended action plan
- A draft follow-up email to the student

If `OPENAI_API_KEY` is not set, the app falls back to deterministic mock output so all features remain functional offline.

---

## Risk scoring

Students are scored on five signals:

| Signal | Severity | Points |
|---|---|---|
| Inactive 14+ days | High | 40 |
| Progress < 10% | High | 40 |
| 2+ missed live sessions (last 3) | High | 20 |
| Inactive 7–13 days | Medium | 25 |
| Progress 10–29% | Medium | 25 |
| Assignment completion < 60% | Medium | 15 |
| Attendance < 70% | Medium | 15 |

**Score ≥ 60 → High risk · Score ≥ 30 → Medium risk · Below 30 → Low risk**

---

## Re-seeding

To wipe and regenerate all data:

```bash
bin/rails db:seed
```

---

## Project structure

```
app/
  controllers/
    dashboard_controller.rb
    students_controller.rb
    courses_controller.rb
    students/ai_summaries_controller.rb
  models/
    student.rb  course.rb  enrollment.rb  activity.rb  ai_summary.rb
  services/
    risk_assessment.rb       # scoring logic
    ai_summary_service.rb    # OpenAI + mock fallback
  helpers/
    risk_helper.rb           # badge and colour helpers
  views/
    shared/                  # topnav, stat cards, sparkline, AI panel, etc.
    dashboard/show.html.erb
    students/show.html.erb
    courses/
  javascript/controllers/
    ai_panel_controller.js   # copy-to-clipboard, skeleton swap
    search_controller.js     # debounced search
  assets/tailwind/
    application.css          # @import tailwindcss + shadcn @theme tokens
```
