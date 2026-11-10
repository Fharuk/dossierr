# Two accounts, two values: Neon and Gemini, step by step

You're collecting four things in total for `render.yaml`. Two come from here:

| Value | Comes from | Looks like |
| --- | --- | --- |
| `DATABASE_URL` | Neon | `postgresql://neondb_owner:npg_…@ep-…-pooler.eu-west-2.aws.neon.tech/dossier?sslmode=require` |
| `DOSSIER_AI_KEY` | Google AI Studio | `AQ.Ab8…` (new format) or `AIzaSy…` (older keys) |

The other two you make yourself in a terminal: `DOSSIER_PASSWORD` (a hash) and
`DOSSIER_SECRET` (random). Both are one command each, at the end.

Neither signup asks for a card. Keep both tabs open: you'll paste both values
into Render in Part 3 of [DEPLOY.md](DEPLOY.md).

---

## Part A — Neon, the database (about 5 minutes)

### A1. Sign up

1. Go to **https://console.neon.tech** and click **Sign up**.
2. Choose **Continue with GitHub** (simplest; use the same GitHub account you'll
   use for Render) or Google.
3. If Neon asks for a name and company, any answer works; there's no card step.
   You land on **Projects**, empty.

Region note: the region can't be changed later, and it decides how long every
query takes — a page makes several. Whatever you pick, set Render's `region` in
`render.yaml` to the Render region in the same area (`eu-central-1` →
`frankfurt`, `us-west-2` → `oregon`, `us-east-2` → `ohio`, `us-east-1` →
`virginia`). An app in Frankfurt querying a database in us-west-2 adds about
150 ms per query.

### A2. Create the project

1. Click **New Project**.
2. **Project name:** `dossier`.
3. **Region:** `AWS eu-west-2 (London)` or `AWS eu-central-1 (Frankfurt)`. Either
   pairs well with render.yaml's `frankfurt`.
4. **Postgres:** leave the default version (17).
5. Under **Services**, make sure **Postgres database** is the only thing on —
   turn off anything else (Object Storage, Functions, AI Gateway, Neon Auth);
   you don't need them and they add things to manage.
6. Click **Create project**. It takes a few seconds, then opens the project
   dashboard.

You get, automatically: a branch (`production`), a database named `neondb`, a
role named `neondb_owner`, and a compute that sleeps when idle and wakes in
about a second.

### A3. Rename the database to `dossier`

Not required — Dossier migrates whatever database the URL names — but a URL that
says `dossier` is easier to read six months from now.

1. In the left sidebar, click **SQL Editor**.
2. Paste this and click **Run**:

   ```sql
   CREATE DATABASE dossier;
   ```

   (Postgres has no `RENAME DATABASE`; creating the one you want is the way.)

Dossier creates all 43 of its tables inside it on first start.

### A4. Copy the connection string

1. Click **Connect** in the sidebar (or the **Connect** button on the dashboard).
2. In the modal:
   - **Branch:** `production`
   - **Compute:** the read-write one (the only one)
   - **Database:** `dossier`
   - **Role:** `neondb_owner`
   - **Connection pooling:** leave it **on** (the host then contains
     `-pooler`). Dossier handles Neon's pooler correctly — it uses one pooled
     connection with the `pg` driver, and its startup migrations are plain SQL
     applied one file at a time, not Prisma's advisory-locked migrate.
3. The box now shows the full string. Click **Copy**, then paste it somewhere
   temporary (a text file, not a chat).
4. Check it looks like this before moving on:

   ```
   postgresql://neondb_owner:npg_XXXXXXXX@ep-cool-name-12345678-pooler.eu-west-2.aws.neon.tech/dossier?sslmode=require&channel_binding=require
   ```

   - Starts `postgresql://` ✓
   - Has `-pooler` before the first dot of the host ✓ (Neon adds it; Dossier and
     its Postgres driver both accept it)
   - Ends in `/dossier?sslmode=require` (plus `&channel_binding=require` is fine
     — tested against Dossier's driver) ✓
   - The password is the part between `:` and `@`; if it contains `@`, `#` or
     `/`, Neon has already URL-encoded it as `%40` etc., so leave it as is.

That whole line is your `DATABASE_URL`.

**Also copy the unpooled one.** Same modal, same selections, but turn
**Connection pooling off** (or click the **Direct**/unpooled toggle): the host
loses its `-pooler` and the rest is identical. Paste it with the pooled string,
labelled `DIRECT_URL`. Dossier itself uses only the pooled one; the direct one
is there so the container's startup migrations can use it if your pooler won't
hold the advisory lock they take — a real, reported Neon+Prisma failure
(`P1002 … Timed out trying to acquire a postgres advisory lock`). If your first
deploy starts cleanly without it, leave it blank or delete it.

### A5. Check the string before Render, without a database client

This repository has a checker that reads a connection string, names what's
wrong with it, and never prints the password:

```bash
node scripts/local/check-db-url.mjs 'postgresql://…'
node scripts/local/check-db-url.mjs --connect "$DATABASE_URL"   # also opens one connection
```

It catches the copy-paste damage — a `&amp;` where `&` belongs, a markdown link
wrapped around the address, stray spaces, a missing `sslmode`, a `-pooler` host
used where a direct one belongs — and with `--connect` says whether the
password is currently valid.

### A6. Optional: prove it with psql

Only if you have `psql` installed (macOS: `brew install libpq`; Windows:
`winget install PostgreSQL.psql`; Linux: `sudo apt install postgresql-client`):

```bash
psql "postgresql://neondb_owner:…-pooler.eu-west-2.aws.neon.tech/dossier?sslmode=require" -c "select current_database(), version();"
```

It prints `dossier` and a Postgres 17 version line. If it hangs instead, your
network blocks outbound 5432 — some do; Render won't have that problem.

> **One thing to know about free Neon:** the compute sleeps after 5 minutes
> without queries and wakes on the next one (~1 s). Nothing is lost, and it
> means your free hours last the month. Neon also keeps 6 hours of
> point-in-time restore on the free plan, so a mistake is recoverable.

---

## Part B — Google Gemini, the AI (about 5 minutes)

### B1. What you're getting

- A free API key from **Google AI Studio**, no card, no billing account.
- The free tier covers `gemini-3.8-flash` (the model `render.yaml` sets).
- The free tier's prompts and responses **may be used to improve Google's
  products**. For someone's CV and cover letters that's a real consideration —
  read [Privacy](https://github.com/AienTech/dossier/wiki/Privacy) in the wiki
  before you put a full CV through it. If that's not acceptable, skip to the
  alternative at the end of this part.
- Free tier is rate-limited (about 10–15 requests a minute and ~1,500 a day,
  shown in AI Studio rather than published as a table). A job application uses
  a handful of calls, so a normal day fits; a long bulk session can hit a 429,
  and waiting a minute clears it.

### B2. Make the key

1. Go to **https://aistudio.google.com/apikey** (or aistudio.google.com → left
   menu → **Get API key**) and sign in with your Google account.
2. Read and accept the terms if you're asked to.
3. Click **Create API key**.
4. When it asks which Google Cloud project: choose **Create a new project**
   (search "Create new project" in the dropdown if the list is empty). AI Studio
   makes the project for you; you don't need to visit the Cloud console, and
   you don't need billing.
5. It shows the key once. Copy it now — the full string doesn't come back later
   (you can make a new one, but not re-read this one).
6. Paste it into the same temporary text file as the Neon URL.

The key starts with **`AQ.Ab…`** if it's new (Google's current "auth key"
format), or **`AIzaSy…`** if you had an older one. Both are fine — see B4.

### B3. Where it goes in Dossier

Two places, and they do the same thing (the second wins if both are set):

- **Before first start:** `DOSSIER_AI_KEY` in `render.yaml` — that's the value
  you paste into Render's form in Part 3 of DEPLOY.md.
- **Later, or to change the model:** sign in → **Settings → AI provider** →
  radio choice **OpenAI-compatible** → **Server address**
  `https://generativelanguage.googleapis.com/v1beta/openai` → **Model**
  `gemini-3.8-flash` → paste the key in **API key** → **Test connection**.

**Test connection** is the honest check: it lists the models the address serves
(`GET /v1beta/openai/models`), so a green result means the address and key are
right before you spend a single token.

### B4. If the key is the new `AQ.` format and Dossier says the key is invalid

Google moved new AI Studio keys to an "auth key" format in mid-2026, and whether
the OpenAI-compatible endpoint (`/v1beta/openai`, which Dossier speaks) accepts
them has been inconsistent — it depends on when and to which surface the key was
issued. As of a September 2026 report from Google's own developer forum, an
`AQ.` key bound to the **Gemini API** does work with `Authorization: Bearer` on
the OpenAI-compatible route; other reports from the same period say it returned
401 or `Invalid Auth key`. So: try it, and if it fails, work down this list.

| What you see | What it means | Do this |
| --- | --- | --- |
| **Test connection** lists `gemini-3.8-flash` and friends | Nothing. It works. | Use it. |
| `401 Invalid Auth key` / `401 ACCESS_TOKEN_TYPE_UNSUPPORTED` with an `AQ.` key | This key isn't accepted on the OpenAI-compatible route | **1.** In AI Studio → API keys → **Create API key** again and, in the project dropdown, pick an existing Cloud project rather than a new one (keys issued into a project with the Gemini API already enabled are more often the older `AIza` type). **2.** If every new key is `AQ.`, switch the AI provider — see the alternative below. |
| `400 Multiple authentication credentials received` | Something sent two credentials at once (usually a proxy in front adding `x-goog-api-key` while Dossier sends `Authorization`) | Make sure you only set the key in Dossier's **API key** field, not also in `DOSSIER_AI_URL` as `?key=`. |
| `404` on the address | An extra or missing path segment | Use exactly `https://generativelanguage.googleapis.com/v1beta/openai`, nothing after it. Dossier adds `/chat/completions`. |
| `429` | Free-tier rate limit | Wait a minute; lower Scoring → AI to batch less often. |
| `403 … region` | Gemini isn't available in the signup country (EEA/UK/CH restrictions) | The alternative below, hosted elsewhere. |

**The alternative if `AQ.` keys won't talk to the OpenAI-compatible route:**
[Groq](https://console.groq.com) — free tier, no card, ~30 requests/minute,
and its endpoint is plainly OpenAI-compatible
(`https://api.groq.com/openai/v1`, models like `llama-3.3-70b-versatile`). In
Dossier: **OpenAI-compatible** → that address → **Other model…** → the model
name Groq shows → your Groq key → **Test connection**. Dossier doesn't need to
know the difference. Groq's free tier trains on prompts too, unlike its paid
one — same trade-off as Gemini's.

### B5. What Dossier sends, for reference

- Address: `https://generativelanguage.googleapis.com/v1beta/openai`
  (Dossier rewrites any of `…/v1beta`, `…/v1` or the bare host to this; see
  `src/lib/ai/providers/servers.ts`)
- Calls: `POST /v1beta/openai/chat/completions` with `Authorization: Bearer <key>`,
  structured output via `response_format` (`json_schema`) — verified working
  against a stand-in server in this repo.
- Model: `gemini-3.8-flash`. Thinking models spend part of the response budget
  thinking before answering; Dossier counts those tokens in Usage.

---

## Part C — The two values you make yourself (2 minutes)

### C1. Your sign-in password, as a hash

Dossier never stores the password, only an argon2id hash of it. Make one:

- **With Docker:**
  ```bash
  docker run --rm -it ghcr.io/aientech/dossier hash-password
  ```
- **Without Docker**, in this repository with Node 24 (`nvm use 24`, then
  `corepack enable && yarn install`):
  ```bash
  yarn hash-password
  ```

Type the password twice (it doesn't show while you type). It prints one line
starting `argon2id:` — that whole line is `DOSSIER_PASSWORD`, and the password
you typed is what you'll sign in with. Changing your mind later means making a
new hash and updating the variable; nothing else changes.

### C2. The session secret

```bash
openssl rand -base64 32
```

(Windows PowerShell: `[Convert]::ToBase64String((1..32 | % { Get-Random -Max 256 }))`.)

That 44-character line is `DOSSIER_SECRET`. It signs your session cookies and
encrypts API keys stored in the database, so keep it out of public places; if
you rotate it, you'll sign in again and re-enter any keys saved in Settings.

### C3. Your four values

| Variable | Value |
| --- | --- |
| `DATABASE_URL` | Part A4, the `-pooler` string |
| `DIRECT_URL` | Part A4, the same string without `-pooler` (only needed if a deploy stops at the migrations — see A4) |
| `DOSSIER_PASSWORD` | Part C1 (`argon2id:…`) |
| `DOSSIER_SECRET` | Part C2 |
| `DOSSIER_AI_KEY` | Part B2 |

That's everything Render's blueprint asks for. Delete the temporary file once
they're pasted into Render — Render stores them encrypted and won't show them
again either, so keep a copy in a password manager.

---

## Common stumbles, in one place

| Symptom | Cause | Fix |
| --- | --- | --- |
| Render deploy stops: `applying the database migrations failed`, `P1002 … advisory lock` | The startup migrations couldn't hold their session through this pooler | Set `DIRECT_URL` to the unpooled string (Part A4) and redeploy: `docker/start.sh` migrates over it and keeps `DATABASE_URL` for the app. |
| Render deploy fails: `Can't reach database server` | Wrong host/region, or the project was deleted | Re-copy from **Connect**; check the host has `-pooler` and the region matches the project. |
| `password authentication failed` | Password changed, or a stray space/newline from copy-paste | Re-copy the whole string, from `postgresql://` to the end. |
| Dossier starts, but every AI action says the provider is not configured | `DOSSIER_AI_KEY` empty and nothing saved in Settings | Set the variable, or fill Settings → AI provider. |
| PDF download fails with a memory error | Render free's 512 MB, Chromium's peak | See DEPLOY.md Part 4 (Oracle: 12 GB). Previews and drafts still work. |
