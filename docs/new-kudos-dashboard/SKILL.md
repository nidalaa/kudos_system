---
name: new-kudos-dashboard
description: Use when an HR teammate (or any non-technical person) wants to build a new analytics dashboard for the Kudos System app, or types /new-kudos-dashboard. Guides them from a blank repo to a live dashboard on Railway, doing all the coding for them while they direct the design and confirm what they see. Trigger whenever someone says they want to "build a kudos dashboard", "add charts to the kudos app", "report on kudos data", or anything similar — even if they don't explicitly mention this skill.
---

# New Kudos Dashboard Workflow

## Overview

Guides a non-technical person (typically someone on HR) through building a brand-new analytics dashboard inside the Kudos System Rails app — from setting up their laptop to seeing the dashboard live on Railway.

**Your role:** You are their technical partner. They are the design authority — they decide what the dashboard should show and what it should look like. You write all the code. They never need to read, edit, or understand a line of it.

**Tone throughout:** Warm, patient, jargon-free. Translate every technical step into plain English. Celebrate small wins. Never paste raw error messages at them — read the error yourself, then explain in human terms what's happening and what you're going to try.

**Golden rule:** They should always know (a) what's happening right now, (b) what they need to do next, and (c) when something is "saved" vs "still being worked on." Vague status leaves people anxious.

---

## Step 1 — Welcome and check the workspace

Greet them warmly and explain in one sentence what's about to happen:

> "Hi! I'm going to help you build a new dashboard for the Kudos app. You'll tell me what you want to see; I'll do all the coding. We'll preview it together in your browser, and once you're happy, we'll publish it. No coding experience needed. Ready?"

Then quietly check three things — don't show them the commands:

1. Are we in the kudos repo? Run `git remote get-url origin` and confirm it includes `nidalaa/kudos_system`. If not, ask if they have the project folder open. If they don't have it yet, walk them through the **First-time setup** section below.
2. Are they on `main` and clean? Run `git status` and `git rev-parse --abbrev-ref HEAD`. If they have uncommitted changes, ask gently: "I noticed there's some unfinished work in this folder. Should I save it on a branch for later, or would you like to throw it away?" Don't act until they answer.
3. Is the database ready? Run `rails db:version 2>&1`. If it errors, run setup (see Step 2).

---

## First-time setup (only if they don't have the project yet)

This whole section is a side-quest. Only do it if `git remote get-url origin` failed or they explicitly say "I haven't set this up before."

Anticipate confusion. Translate every term:

- **"Terminal" / "command line"** → "the black-text window for typing commands to your computer"
- **"Git"** → "the system that tracks every version of the project, like Google Docs revision history"
- **"SSH key"** → "a secret handshake between your computer and GitHub so they trust each other — set up once, never again"
- **"Clone"** → "download a copy of the project"

Walk through:

1. **Ask their OS** — Mac or Windows. Most of this assumes Mac; if Windows, gently say you'll guide them through equivalents.
2. **Check Ruby is installed** — `ruby -v`. If missing, point them to https://www.ruby-lang.org/en/documentation/installation/ with a brief "this is a one-time install."
3. **Check Postgres is running** — `pg_isready`. If not, on Mac: `brew install postgresql@16 && brew services start postgresql@16`.
4. **Check GitHub access** — `ssh -T git@github.com`. If it fails, walk through SSH key setup (generate with `ssh-keygen -t ed25519 -C "their email"`, copy `cat ~/.ssh/id_ed25519.pub`, paste into github.com → Settings → SSH Keys).
5. **Clone the repo** — `git clone git@github.com:nidalaa/kudos_system.git` and `cd kudos_system`.

Then return to Step 1.

---

## Step 2 — Get the app running

Tell them: "I'm going to get the app running on your computer. This usually takes a minute."

Run silently, one at a time, and only report problems in plain English:

```bash
bundle install
```

If `.env` is missing, copy from the example:

```bash
[ -f .env ] || cp .env.example .env
```

Open `.env` and check whether `ANTHROPIC_API_KEY` looks set (not the placeholder `sk-ant-...`). If it's the placeholder, say:

> "For the dashboard itself, we don't actually need the AI key — that's only for the part that reads Slack messages. I'll leave it as-is. If you ever want to use the AI features, you'll need an Anthropic API key, but we can skip that today."

Then prepare the database:

```bash
rails db:create db:migrate db:seed
```

If the database already exists, that's fine — keep going. Only show them an error if something actually broke. If the error is "database already exists," silently skip it. If it's something else (e.g., port conflict, missing extension), translate: "There's a small issue with Postgres — let me look at it." Investigate and fix; don't paste the raw error.

---

## Step 3 — Make sure there's data to look at

A dashboard with no data is depressing. Check the count:

```bash
rails runner "puts Kudos.where(status: 'approved').count"
```

**If the count is 0 or very low**, offer to add sample data:

> "Right now your database doesn't have many kudos in it, so the dashboard would look empty. Want me to add some realistic sample data so you can see the dashboard in action? It'll be obviously fake (made-up names) and we can clear it out anytime."

If yes, generate ~50–100 realistic-looking kudos via a Rails runner script. Use the existing categories from `db/seeds.rb`. Make sure to spread the `slack_timestamp` across the last 90 days so the time-period filters have something to show, and vary the giver/receiver so the leaderboards aren't flat. Set `status: "approved"`.

Don't show them the script — just say "Done! I added 87 sample kudos." or similar.

---

## Step 4 — Create a working branch

Explain in plain English:

> "I'm going to put your work on its own 'branch' — think of it like a separate copy of the project that only has your dashboard in it. That way, until you're 100% happy, nothing on the live website changes. We'll merge it in at the end."

Create a branch with a friendly, descriptive name based on what they want to build (you'll learn this in Step 5, so come back here after — or pick a temporary name like `dashboard/wip` and rename later):

```bash
git checkout -b dashboard/<short-name>
```

---

## Step 5 — Start the preview server

Check if it's already running:

```bash
lsof -i :3000 | grep LISTEN
```

If not, start it in the background:

```bash
nohup bin/rails server -p 3000 > /tmp/kudos-server.log 2>&1 &
```

Wait a few seconds, then say:

> "Your local preview is ready! Open this link in your browser:
> **http://localhost:3000/kudos-review**
>
> That's the existing app. Take a quick look so you know what's there now. Then come back here and tell me what you'd like the new dashboard to show."

---

## Step 6 — Discover what they want on the dashboard

This is the most important conversation in the whole flow. Slow down here.

Ask open-endedly, but offer concrete starting points. Many non-technical people freeze if you ask "what do you want?" with no prompts.

> "What would you like to see on this dashboard? Here are some ideas to get you started — pick any that sound useful, or describe something completely different:
>
> - **Top people** — leaderboards of who's giving and receiving the most kudos
> - **Categories breakdown** — which kinds of kudos (teamwork, innovation, etc.) come up most
> - **Trends over time** — are kudos going up, down, steady?
> - **Activity by channel or team**
> - **Recent highlights** — most-reacted-to kudos
>
> 'I don't know' is a totally fine answer — I can pick a starter set and we'll adjust as we go."

If they say "I don't know," propose a sensible default set:

> "No problem! Here's what I'd suggest as a starting point. We can change anything you don't like:
> - Total kudos this month (one big number)
> - Top 10 receivers
> - Kudos broken down by category (pie chart)
> - Trend over the last 6 weeks
> - Top 10 givers
>
> Sound good?"

Ask follow-ups one at a time:
- "Do you want to be able to filter by time period (last week, last month, etc.)?"
- "On the leaderboards, do you want any extra detail when you hover a name?"

Capture their answers into a short bullet list and read it back: "OK — here's what I'll build. Does this match what you have in mind?"

---

## Step 7 — Show three mockups (as a real HTML preview)

Before writing any code, show them three different visual layouts as a **rendered HTML preview** so they can actually see what they're choosing. **Do not skip this step**, even if they seem decisive. Seeing real layouts helps non-designers articulate what they actually want.

Write a single self-contained HTML file at `/tmp/kudos-mockups.html` with three mockup options side-by-side (or as three tabs). Use Tailwind via the CDN (`<script src="https://cdn.tailwindcss.com"></script>`) so it matches the look of the real app. Use the same color palette and rounded-card style as `app/views/kudos/index.html.erb`. Use hardcoded placeholder numbers and names ("Sarah P. — 32 kudos", a pie chart drawn as a colorful SVG, etc.) — no real data needed for mockups.

Each mockup should reflect the same content but a different arrangement, for example:

- **Option A — "Headline numbers first"**: Big total at the top, leaderboards in two columns, trend chart full-width at the bottom.
- **Option B — "Visual first"**: Big pie chart and trend chart on top, leaderboards below.
- **Option C — "Single column scroll"**: Everything stacked top-to-bottom, mobile-friendly.

Tailor the three options based on what they said in Step 6. If they specifically asked for, say, a category breakdown but didn't mention leaderboards, all three options should include the category breakdown but vary the surrounding layout.

Add a one-sentence pitch above each mockup ("This one is great if you want the headline numbers to grab attention first."). Use real-looking SVG/CSS charts inside the mockups — not "[chart goes here]" placeholders. A non-designer can't picture an empty box.

Open the file in their default browser:

```bash
open /tmp/kudos-mockups.html
```

Then say:

> "I've opened three layout options in your browser. Take a look and tell me which one feels closest to what you want — or if you'd like to mix elements from a few of them (e.g., 'leaderboards from Option A, charts from Option B')."

If they want a mix, restate the chosen mix back in words and confirm before building. Don't update the HTML preview to show the mix — you've already learned what you need to learn.

---

## Step 8 — Build in small, named chunks

This is the core of the work. Build the dashboard in chunks. **After every chunk, have them refresh the browser and confirm it looks right before continuing.** This is non-negotiable — never build two chunks back-to-back without their confirmation in between.

Suggested chunking (adapt as needed):

| Chunk | What to build | What they should see |
|-------|---------------|----------------------|
| 1 | Route + empty page with a header | A page that loads at `/dashboard` (or root) with just a title |
| 2 | Totals tile + period dropdown | The big total number; switching the dropdown updates it |
| 3 | First chart (e.g., category pie) | One real chart on the page |
| 4 | Leaderboards (top receivers, top givers) | Two lists of names with numbers |
| 5 | Trend chart over time | A weekly-trend chart |
| 6 | Hover tooltips, polish, link to kudos management | Hover details work; "Manage kudos →" link in the header |

For each chunk:

1. **Brief them in plain English:** "Next I'm going to add the big total-kudos number to the top of the page. Should take about a minute."
2. **Do the work.** Don't narrate the code edits in detail; one or two sentences is enough.
3. **Recap when done:** "OK — added it. Please refresh **http://localhost:3000/dashboard** and tell me how it looks. You should see a big number near the top showing the total kudos."
4. **Wait for them to look.** Do not move on until they confirm.
5. **At natural stopping points** (typically every 1–2 chunks of visible progress), suggest a commit:

   > "This is a good moment to save your progress. Want me to commit what we've done so far? That way if we change our minds later, we can always come back to this version."

   If yes, commit with a friendly message:

   ```bash
   git add .
   git commit -m "feat(dashboard): <short description of what's now visible>"
   ```

   Tell them "Saved! ✓"

---

## Step 9 — When something looks wrong

Two failure modes — diagnose which one first.

### Mode A: It looks wrong but the page loaded

(Wrong colors, off layout, missing data, chart looks weird.)

Ask, gently and specifically:

> "Thanks for catching that! Can you describe what you see vs. what you expected? For example: 'the pie chart only shows two categories but there should be six' or 'the numbers on the leaderboard look too small.'"

Then fix the code, refresh, and have them re-check.

### Mode B: The page is blank, broken, or shows an error

You need to see what the browser saw. Don't ask them to paste a full error stacktrace. Instead, ask one clear thing at a time:

> "Could you do me a favor? In the browser, right-click anywhere on the page and click 'Inspect.' A panel will open — click the **Console** tab. You'll see some text in there, possibly red. Could you copy whatever's there and paste it back to me?"

If they're not sure how to find Console, walk them through it step by step:
1. "Right-click on the page → 'Inspect.'"
2. "A panel opens, usually on the right or bottom."
3. "Look for tabs at the top of that panel. Click **Console**."
4. "Copy any red text and paste it here."

If the issue is server-side (not in the browser), check `/tmp/kudos-server.log` yourself. Don't ask them to look at server logs.

Once you understand the problem, explain in plain English: "Looks like the chart library wasn't loading — I'm going to fix that now." Then fix it. Don't make them feel like they did something wrong.

---

## Step 10 — Final review

Once all chunks are built and they're happy with each piece, do a final pass together.

> "Great work! Before we publish, let's do one last review together. Refresh the dashboard and try each thing:
> - Click each option in the time-period dropdown — do the numbers and charts change?
> - Hover the names on the leaderboards — does the detail box appear?
> - Click the 'Manage kudos →' link — does it take you back to the review page?
> - Does anything feel slow, confusing, or out of place?"

If anything is off, fix it. Loop until they say everything looks right.

---

## Step 11 — Publish (push and open a Pull Request)

Tell them what's about to happen:

> "Time to publish! Here's how it works: I'll send your dashboard up to GitHub on its own branch and open something called a **Pull Request** — that's a way of saying 'I'd like to add this to the live website, please review.' Once it's approved and merged, Railway will automatically put it on the live site within a couple of minutes. Sound good?"

Wait for confirmation. Then:

1. Make sure all changes are committed:

   ```bash
   git status
   git add .
   git commit -m "feat(dashboard): <short, friendly description>"  # only if there are unstaged changes
   ```

2. Push:

   ```bash
   git push -u origin HEAD
   ```

3. Open a PR with `gh`. Write the PR body in plain English so a reviewer (technical or not) can understand what changed. Use this template:

   ```bash
   gh pr create --title "New analytics dashboard" --body "$(cat <<'EOF'
   ## What this adds
   A new dashboard at `/dashboard` (also the homepage) showing:
   - <bullet list of what's on it>

   ## How to test
   - Open `/dashboard` locally
   - Try each time-period option
   - Hover the leaderboards
   - Click 'Manage kudos' to confirm navigation back to the review page

   ## Built with
   Built by <person's name> with Claude's help, using the `new-kudos-dashboard` skill.
   EOF
   )"
   ```

4. Show them the PR URL:

   > "Your Pull Request is ready! Here's the link — click to view it on GitHub:
   > **<PR URL>**
   >
   > A teammate will look it over and merge it in. Once they do, Railway will publish it automatically. You can keep this link to track progress."

---

## Step 12 — Verify deploy (after merge)

This step might happen later, after a teammate merges the PR. If they come back and ask "is it live yet?":

> "Once your PR is merged into `main`, Railway usually takes 1–2 minutes to publish. Let's check together — can you open the live site at <live-url> and click to the dashboard?"

If something's wrong on the live site:

1. **Build error** — Check Railway's deploy logs (or GitHub Actions if configured). Translate the issue.
2. **Old version showing** — Have them hard-refresh (Cmd+Shift+R on Mac, Ctrl+Shift+R on Windows).
3. **Differs from local** — Compare. Often it's a missing migration or seed; investigate and patch.

Don't leave them hanging — keep at it until the live site matches local.

---

## Step 13 — Stop the dev server

**Always do this at the end of every session**, even if the conversation ends abruptly.

```bash
kill $(lsof -ti :3000) 2>/dev/null && echo "stopped" || echo "nothing to stop"
```

Then say:

> "I've stopped the preview server — your computer's resources are all yours again. Thanks for building this with me!"

---

## Commit rules

- **One chunk = one commit, when visible progress is confirmed.** Don't bundle multiple unrelated changes into one commit. Don't commit changes the user hasn't confirmed in the browser.
- **Commit message format:** `feat(dashboard): <plain English description of what now works>`. Examples: `feat(dashboard): show total kudos for selected period`, `feat(dashboard): add top-10 receivers leaderboard with hover details`.
- **Never push directly to `main`.** Always work on a `dashboard/<name>` branch and open a PR.
- **Never commit `.env` or any file containing keys/passwords.** If they accidentally edited `.env`, restore it before committing.

---

## Things to never do

- Never show them raw stacktraces, SQL errors, or migration output unless they explicitly ask. Translate.
- Never assume terminal/git/SSH/Postgres knowledge. Walk through each.
- Never skip the browser-refresh confirmation between chunks. Even if you're sure it works.
- Never push to `main`. Always a branch + PR.
- Never leave the dev server running at end of session.
- Never make them feel like they broke something. Frame issues as "let me adjust this" — your code, your responsibility.
