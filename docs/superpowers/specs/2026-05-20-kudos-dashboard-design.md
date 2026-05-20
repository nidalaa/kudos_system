# Kudos Analytics Dashboard — Design Spec

**Date:** 2026-05-20
**Route:** `/` (root) → `dashboard#index`. Kudos review remains at `/kudos-review`.

---

## Layout

```
┌─ Nav: "Kudos Analytics" | [period picker] | → Manage kudos ─────────────┐
│  142 approved kudos this period                                          │
├─────────────────────────────┬────────────────────────────────────────────┤
│  [Receivers | Givers] tabs  │  BY CATEGORY (donut, Chart.js)            │
│                             ├──────────────┬─────────────────────────────┤
│  Rank list, hover → detail  │  RECEIVERS   │  GIVERS                    │
│  panel (see below)          │  51 unique   │  38 unique                 │
├─────────────────────────────┴──────────────┴─────────────────────────────┤
│  WEEKLY TREND BY CATEGORY (stacked bar, Chart.js)  │  MOST BACKED UP    │
└────────────────────────────────────────────────────┴────────────────────┘
```

---

## Time Period

URL param `?period=` with values: `week`, `2weeks`, `month` (default), `quarter`, `year`, `custom`.
Custom also accepts `?from=YYYY-MM-DD&to=YYYY-MM-DD`.
All queries scoped to `kudos.created_at` within the selected range and `status = 'approved'`.

---

## Components

### Leaderboard (left panel)
- Two tabs: **Receivers** (default) and **Givers**.
- Top 10 per tab, ranked by kudos count descending.
- Clicking/hovering a name expands an inline detail panel showing:
  - Kudos by category (horizontal bar per category, count right-aligned).
  - Mini sparkline — kudos per week over the period (Chart.js bar, small).
  - Top 3 most backed-up kudos for this person: `reason` (not `original_message`), reaction count, category, counterpart name.
- All leaderboard data pre-loaded as JSON in a Stimulus data attribute — no AJAX.

### By Category (right, top)
- Donut chart via Chart.js. Centre label shows total count.
- Legend lists all categories with percentage.
- Category colours consistent across all charts: fixed palette keyed on category name.

### Unique counts (right, bottom)
- Two stat cards: unique receivers count, unique givers count.

### Weekly Trend (bottom left)
- Stacked bar chart via Chart.js. X-axis = ISO weeks in period. Y-axis = kudos count. One dataset per category, same colour palette.

### Most Backed-Up Kudos (bottom right)
- Top 3 kudos globally sorted by `array_length(reactions_from, 1) DESC`.
- Each card: receiver name, reaction count badge, `reason` (truncated), category, giver name.
- Gold/silver/bronze left border for rank 1/2/3.

---

## Tech

- **Controller:** `DashboardController#index`. All data computed server-side, passed to view.
- **Charts:** Chart.js via CDN (same pattern as Tailwind CDN in layout).
- **Stimulus:** `dashboard_controller.js` — tab switching, detail panel expand/collapse, Chart.js init.
- **Period picker:** Plain links with `?period=` params. Active period highlighted. Custom range uses two date inputs + a form GET.
- **Weekly grouping:** PostgreSQL `date_trunc('week', created_at)` — no extra gems needed.

---

## DB queries (all scoped to approved kudos in period)

| Data | Query |
|------|-------|
| Total | `scope.count` |
| Unique receivers | `scope.distinct.count(:receiver_id)` |
| Unique givers | `scope.distinct.count(:giver_id)` |
| By category | `scope.group(:category).count` |
| Top receivers | `scope.group(:receiver_id).order('count_all desc').limit(10).count` |
| Top givers | `scope.group(:giver_id).order('count_all desc').limit(10).count` |
| Weekly trend | `scope.where(category: cat).group("date_trunc('week', created_at)").count` per category |
| Most backed-up | `scope.select('*, array_length(reactions_from,1) as rxn_count').order('rxn_count desc nulls last').limit(3)` |
| Per-person top 3 | Same as most backed-up, filtered by receiver_id or giver_id |
