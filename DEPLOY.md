# Deploying Dossier for $0

Dossier is one long-running Node process with a database, some schedules of its
own (nightly backups at 03:00, the job agent's daily run, the inbox check) and
headless Chromium to print PDFs. That rules a few popular free hosts out
before we start:

| Host | Why not, for Dossier |
| --- | --- |
| **Vercel** (Hobby) | Serverless functions: no long-lived process, so no PDF browser and no schedules; the database would need to be remote and the filesystem is gone between requests. Dossier is also a single-instance app by design. |
| **Hugging Face Spaces** | Since July 2026 Docker Spaces need PRO ($9/mo); only static and two ZeroGPU Gradio Spaces are free. |
| **Koyeb** | Its free Starter plan was withdrawn for new accounts in February 2026. |
| **Fly.io / Railway** | No usable free tier (Railway only a small expiring credit). |
| **Cloudflare Workers** | No Node filesystem, no Chromium, no long-lived process. |

What's left, and what this guide uses:

| Piece | Free choice | Card needed | Catch |
| --- | --- | --- | --- |
| App | **Render** web service (Docker) | No | 512 MB RAM, sleeps after 15 min idle (~1 min to wake), 750 h/month, no disk |
| Database | **Neon** Postgres | No | 0.5 GB, scale-to-zero when idle (wakes in ~1 s) |
| AI | **Google Gemini** free tier | No | ~10 req/min, 1,500/day; Google may use the prompts |
| App (later, better) | **Oracle Cloud Always Free** | Yes (verification only) | 2 ARM cores / 12 GB, always on, 200 GB disk |

The app on Render with Neon costs nothing and never asks for billing details.
Oracle's is the better home once you're past signup: no sleeping, no 512 MB
ceiling, and Chromium has room to print PDFs.

---

## Part 1 — Neon (the database), 5 minutes

1. https://console.neon.tech → sign up with GitHub or Google (no card).
2. **Create project**: name it `dossier`, pick the region nearest you
   (AWS `eu-central-1` or `eu-west-2` for Lagos), Postgres 17.
3. On the project's **Connect** dialog, copy the **connection string**. It looks
   like
   `postgresql://neondb_owner:xxxxxxxx@ep-cool-name-123456-pooler.eu-west-2.aws.neon.tech/neondb?sslmode=require`.
   - Use the **pooled** host (the one with `-pooler`): free-project Postgres and
     a 512 MB container do better with it.
   - Rename the database in the string to `dossier`, or create it: Neon's SQL
     editor takes `CREATE DATABASE dossier;`. Dossier migrates whatever
     database the URL names.
4. Keep the string: it's `DATABASE_URL` below.

Dossier creates its own tables on first start (43 migrations, then the themes).

## Part 2 — Gemini (the AI), 2 minutes

1. https://aistudio.google.com/apikey → **Create API key** (no card, no billing
   account needed).
2. Keep it: it's `DOSSIER_AI_KEY` below.

Dossier reaches Gemini through the OpenAI-compatible endpoint Dossier already
speaks, at
`https://generativelanguage.googleapis.com/v1beta/openai` with the model
`gemini-3.8-flash`. Both are set in `render.yaml`; the model can be changed in
**Settings → AI provider** if you want another (Gemini's "thinking" models —
`gemini-3.8-flash` included — spend some of the answer's tokens on thinking
first, which Dossier accounts for).

## Part 3 — Render (the app), 10 minutes

### 3.1 Put the repo on GitHub, public

Render's free plan builds public repositories only. This checkout is already a
Git repository with the deploy files in it; push it:

```bash
git add -A && git commit -m "Dossier + deployment"
gh repo create dossier-app --public --source=. --remote=upstream --push
```

(Two remotes is fine: `origin` is where this checkout syncs, `upstream` is what
Render builds. Any later change: `git push upstream HEAD:main`.)

### 3.2 Make the three secrets

On any machine with Node 24 (`nvm use 24`), in this repository:

```bash
yarn hash-password            # type the password you'll sign in with, twice
openssl rand -base64 32       # DOSSIER_SECRET
```

`yarn hash-password` prints one line starting `argon2id:` — that's
`DOSSIER_PASSWORD`. Dossier stores only the hash.

### 3.3 Deploy the blueprint

1. https://dashboard.render.com → sign up with GitHub (no card) → **New →
   Blueprint**.
2. Connect the `dossier-app` repository. Render reads `render.yaml` and shows
   one service, `dossier`, free plan, region Frankfurt. **Apply**.
   Render's first blueprint on a new account asks for a card to verify the
   account; it isn't charged, and the free plan is what the blueprint asks for
   (`plan: free`, no disk).
3. It asks for the four values marked as secrets:
   - `DATABASE_URL` — the Neon string from Part 1
   - `DOSSIER_PASSWORD` — the `argon2id:` line
   - `DOSSIER_SECRET` — the random string
   - `DOSSIER_AI_KEY` — the Gemini key from Part 2
4. First deploy takes 10–15 minutes: it installs the dependencies, builds the
   standalone server, and installs Chromium for the PDFs.
5. When it says **Live**, open the URL (`https://dossier-xxxx.onrender.com`)
   and sign in with the password you hashed.

The container runs `docker/start.sh`: migrations → the built-in themes → the
server. `/api/health` is the health check.

### 3.4 What to expect from the free plan

- **Sleep.** After 15 minutes without a request it stops; the first visit
  afterwards waits ~1 minute. Nothing is lost — the database is Neon's.
- **Schedules while asleep don't fire on time.** The nightly backup and the
  job agent's run happen when the service next wakes. If you rely on the job
  agent, move to Part 4.
- **No disk.** `/data` (export zips, the backup files, Chromium's temp files)
  is empty on each new container. Your applications, profile and documents are
  in Neon.
- **512 MB.** Chromium is the peak. The project measures ~520 MB for a print
  once the browser is running, so **PDF downloads are the first thing that may
  hit the ceiling**; previews, chat and drafts don't use it. If a PDF fails
  with a memory error, that's why — Part 4 fixes it.
- **5 GB bandwidth/month** (down from 100 GB in April 2026). Fine for one
  person; not a public service.
- **Keep it awake (optional).** A free uptime monitor (UptimeRobot, cron-job.org)
  hitting `/api/health` every 5 minutes keeps it up 24/7, inside the 750 h/month
  (a month is ~744 h). It also keeps Neon awake.

## Part 4 — The better free home: Oracle Cloud (optional, 25 minutes)

When the 512 MB or the sleeping annoys you, `deploy/oracle/` has a Compose file
and Caddy config for Oracle's Always Free ARM server: **2 cores, 12 GB RAM,
always on, 200 GB disk, 10 TB/month**, forever, on the same Neon database and
Gemini key. Step by step: [`deploy/oracle/README.md`](deploy/oracle/README.md).

Signup asks for a card for identity verification (a ~$1 hold, refunded); no
Always Free resource is billed. The project's Docker image is built for ARM as
well as x86, so it runs there as it is.

Moving is: start the Oracle stack, then sign in there — same Neon database,
same password, all your data already present. Point the DuckDNS name at the new
IP, and stop the Render service.

## Part 5 — Making every feature work, for free

| Feature | Free setup | Notes |
| --- | --- | --- |
| Profile, resumes, themes | — | Local to the database. |
| **PDF download** | Chromium in the container | Free on both hosts; on Render's 512 MB it's the memory peak. |
| **New application, matching, drafts, refine chat, letters** | Gemini key | ~2–4 calls per application, so a few applications a day sit well inside 1,500/day. |
| **Job scoring** | Gemini (Scoring → AI) | Jev by TypeSafe needs a key; AI needs none. |
| **Find jobs** | `freehire` (default in `render.yaml`) | No key: company career pages. JSearch (LinkedIn/Indeed) and Adzuna have free tiers but ask for their own signup and keys — add them in Settings → Job search. |
| **Startups** | — | Reads YC and Hacker News; no key. |
| **Job agent** | Gemini | Needs the app awake at its scheduled time: reliable on Oracle, catch-up on Render. |
| **Gmail + Calendar** | Your own Google OAuth client | Free: create a client in Google Cloud Console (Gmail API + Calendar API), add `<your-url>/api/google/callback` as a redirect URI, publish the consent screen (while it's in "Testing", Google expires the token after 7 days). Set `DOSSIER_PUBLIC_URL` to your URL so the redirect always matches. |
| **Claude/MCP connector** | — | Your own Claude plan; nothing on the server. |
| **Backups & export** | The database | Export from Settings → Your data (works on Render); the nightly file backup needs the Oracle box's disk to be kept. |
| **Usage ping** | `DOSSIER_TELEMETRY=off` (set) | Never asks, never sends. |

## Costs, exactly

| Item | Cost |
| --- | --- |
| Render free web service | $0 (750 h/month; no card) |
| Neon free Postgres | $0 (0.5 GB; no card) |
| Gemini free tier | $0 (no card) |
| Oracle Always Free (optional) | $0 (card for verification only) |
| DuckDNS name (Oracle only) | $0 |

Nothing here has an expiry date. The things that *would* cost money — Render's
disk or a bigger instance, Neon's paid plans above 0.5 GB, Oracle beyond the
Always Free shape — are all optional and none are needed for one person's job
search.
