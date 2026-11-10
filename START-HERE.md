# Dossier, from zero, for free

A tick-list. Do the boxes in order. Each box is one small action.

**Before you start, you need:**

- A computer with a browser. You can do all of this on the browser alone.
- A **GitHub** account you can log into. Yours is `Fharuk`.
- A **Google** account (for the AI key). A normal Gmail one works.
- About **1 hour**. Most of it is waiting.

**Words used in this guide**

- **Repo** = your project's folder on GitHub. Yours is `Fharuk/dossierr`.
- **Service** = one running copy of Dossier on the internet.
- **Env var** = a setting you type into a website form. Nothing to install.
- **Terminal** = the black window where you type commands.

**The four things you'll collect** (put them in a notes app as you go):

1. A **database address** — where your data lives.
2. A **hash of your password** — the password you'll log in with, scrambled.
3. A **long random string** — Dossier's secret.
4. An **AI key** — so Dossier can write for you.

**What this costs**

| Thing | Cost | Card? |
| --- | --- | --- |
| Your code on GitHub | $0 | No |
| Render (runs the app) | $0 | No |
| Neon (stores the data) | $0 | No |
| Google Gemini (the AI) | $0 | No |

---

# A. Put your code on GitHub, ready for Render

Render builds from your **`main`** branch, and it has to be a **public** repo.

Your repo right now is **private**, and its `main` branch holds only the
original `README.md` — all of Dossier's code is on a different branch
(`arena/ff06d40c-dossierr`). So:

- [ ] **A1.** Open https://github.com/Fharuk/dossierr/settings and scroll to
      **Danger Zone** at the bottom.
- [ ] **A2.** Click **Change visibility** → **Change to public** → type the repo
      name to confirm.
- [ ] **A3.** Open https://github.com/Fharuk/dossierr/branches.
- [ ] **A4.** Find the branch `arena/ff06d40c-dossierr` and click the **…** or
      **Change default branch** button, and make it the default.
      (If you'd rather keep `main` as the default, skip this — instead, open a
      pull request from that branch to `main` and click **Merge pull request**,
      then **Confirm merge**.)

      Either way, the point is: the branch Render builds must contain
      `render.yaml`, `Dockerfile` and `docker/`. That's the branch with the
      code.
- [ ] **A5.** Check: on
      https://github.com/Fharuk/dossierr/tree/main (or your new default
      branch) you can see a file called **`render.yaml`**.

> **If you don't want the code public:** Render's free plan only builds public
> repos. Your alternative is the Oracle server in
> [`deploy/oracle/README.md`](deploy/oracle/README.md) — but that one does ask
> for a card for identity checks, so it isn't really "no card". Public is the
> free, no-card path.

---

# B. The database, on Neon (10 minutes)

- [ ] **B1.** Go to https://console.neon.tech and click **Sign up**.
- [ ] **B2.** Click **Continue with GitHub**. Approve what it asks.
- [ ] **B3.** You may see an existing project called **`wispy-river-07125773`**.
      Use it — don't make a new one. Click it. (If it isn't there, click **New
      Project**, name it `dossier`, pick a region, and click **Create
      project**.)
- [ ] **B4.** Look at the left menu. Click **Connect**.
      A box opens with a long line of text starting `postgresql://`.
- [ ] **B5.** In that box:
      - **Branch**: `production`
      - **Database**: `neondb` (or `dossier` if that's what you see)
      - **Role**: `neondb_owner`
      - **Connection pooling**: switch it **ON** (the host name then contains
        `-pooler`)
- [ ] **B6.** Because you pasted a password in a chat earlier, click
      **Reset password** in that box first, then copy the new line.
- [ ] **B7.** Click **Copy** and paste it into your notes. Label it
      **DATABASE_URL**.

      It must look like this shape (yours will differ):

      ```
      postgresql://neondb_owner:someLongPassword@ep-something-1234-pooler.c-5.us-west-2.aws.neon.tech/neondb?sslmode=require
      ```

- [ ] **B8.** Check it. In the box:
      - starts with `postgresql://` ✓
      - has `-pooler` in the middle ✓
      - has `/neondb?sslmode=require` at the end ✓
      - **no** `&amp;` anywhere (that's a copy-paste bug from a web page) ✓

      **That last one matters.** The line you sent me earlier had `&amp;`
      instead of `&`, which would stop Dossier from starting. If you see
      `&amp;`, replace it with `&` by hand.

- [ ] **B9.** *(Only if the deploy later says "migrations failed".)* Copy the
      **same** line a second time, this time with **Connection pooling OFF**
      (so no `-pooler` in it). Label it **DIRECT_URL**. Most people don't need
      it.

---

# C. The AI key, from Google (5 minutes)

- [ ] **C1.** Go to https://aistudio.google.com/apikey and sign in with Google.
- [ ] **C2.** Accept the terms if it asks.
- [ ] **C3.** Click **Create API key**.
- [ ] **C4.** When it asks which project, choose **Create a new project**.
- [ ] **C5.** Copy the key **now** — it's shown only once. Paste it in your
      notes and label it **DOSSIER_AI_KEY**.

      It starts with `AQ.` or `AIza`. Either is fine.

---

# D. Your password and a secret (5 minutes, one web page)

You need two lines of text that a normal person can't type out. Use a free
online tool instead of a terminal.

- [ ] **D1.** Open https://emn178.github.io/online-tools/sha256.html — this
      makes a random string.
      Type any few words (they don't matter) into the box, click **Hash**, copy
      the result. Label it **DOSSIER_SECRET**. It's 64 letters and numbers.
- [ ] **D2.** Now your sign-in password. Dossier won't accept a normal
      password — it wants the **scrambled** version.

      Do this on Render instead, because it has the tool built in (skip to
      **E11** and come back here when it tells you).

      **Or**, if you'd rather do it now, on a computer with Docker installed,
      run this in a terminal and type the password you want twice:

      ```
      docker run --rm -it ghcr.io/aientech/dossier hash-password
      ```

      Copy the line it prints (it starts with `argon2id:`). Label it
      **DOSSIER_PASSWORD**.

---

# E. Put it live on Render (15 minutes, plus waiting)

- [ ] **E1.** Go to https://dashboard.render.com and click **Get Started** →
      **GitHub**. Approve it.
- [ ] **E2.** Click **New** (top right) → **Blueprint**.
- [ ] **E3.** Find `Fharuk/dossierr` in the list and click **Connect**.
      (If you don't see it, click **Configure account** /
      **Install GitHub App** and give Render access to that repo.)
- [ ] **E4.** Render shows a service called **`dossier`**, free plan. Click
      **Apply** or **Create**.
- [ ] **E5.** If Render asks for a **card**, stop and tell me — don't enter one.
- [ ] **E6.** Now Render asks you to fill in some values. There are **four**.
      For each one: click the field, paste from your notes, press Enter.

      | The field name Render shows | Paste what you saved in |
      | --- | --- |
      | `DATABASE_URL` | B7 |
      | `DOSSIER_PASSWORD` | D2 (the `argon2id:` line) |
      | `DOSSIER_SECRET` | D1 |
      | `DOSSIER_AI_KEY` | C5 |

      If a field called `DIRECT_URL` appears, leave it **empty** for now.

- [ ] **E7.** Click **Create Web Service** (or **Deploy**).
- [ ] **E8.** Wait. It says **Building**, then **Deploying**. This takes
      **10 to 15 minutes** the first time. Get a drink. Don't click
      redeploy.
- [ ] **E9.** When the dot next to `dossier` turns **green** and says **Live**,
      click the address at the top. It looks like
      `https://dossier-xxxx.onrender.com`.
- [ ] **E10.** You'll see a login screen. Type the password you chose in D2
      (**not** the `argon2id:` line — the actual password you typed).
- [ ] **E11.** You're in. Dossier asks you to fill in your profile first.

---

# F. If something goes wrong

Look at the **Logs** tab of your Render service. Find the **last red line**.
Compare it here.

| What the log says | What it means | The fix |
| --- | --- | --- |
| `applying the database migrations failed` | Render can't set up the tables | Fill in `DIRECT_URL` (B9), then **Manual Deploy** |
| `Can't reach database server` | The database address is wrong or the project is asleep/gone | Re-copy `DATABASE_URL` (B6–B7) |
| `password authentication failed` | The database password changed | Reset it in Neon (B6) and paste the new line |
| `SASL` / `channel_binding` / `invalid connection string` | There's an `&amp;` or a space in the line | Paste the line again, then check it has no space and no `&amp;` |
| Nothing happens for 2 minutes when you open the site | Normal! The free plan sleeps after 15 minutes idle | Wait about a minute and reload |
| The site loads, but AI actions say "not configured" | The AI key is missing or wrong | Check `DOSSIER_AI_KEY` (C5) |

---

# G. What "free" here means, in plain words

- **It sleeps.** After 15 minutes with nobody using it, Render stops it. Your
  next visit takes about a minute to wake it. Nothing is lost.
- **Your data is safe** — it lives in Neon, not in Render.
- **PDF downloads might fail** with an "out of memory" message, because the
  free plan gives the app only 512 MB. If that happens, tell me; there's a
  free server with 12 GB (Oracle) in
  [`deploy/oracle/README.md`](deploy/oracle/README.md), but it asks for a card
  for identity checks.
- **Nothing here expires or starts charging.** The only way to be charged is to
  click "upgrade" on Render or Neon, which you don't need to do.

---

# H. When you're done

- [ ] **H1.** Delete the text file where you saved the four values, **after**
      Render has accepted them. Render stores them privately.
- [ ] **H2.** Keep your **login password** somewhere you won't lose it. To
      change it later: make a new hash (D2) and update `DOSSIER_PASSWORD` in
      Render → **Environment** → **Save**.
- [ ] **H3.** Neon's password you pasted in chat: you reset it in B6, so the old
      one is dead. Good.

---

## The long versions

If you want the detail behind any step: [`SETUP-NEON-GEMINI.md`](SETUP-NEON-GEMINI.md)
(every field, and the AI key's error messages) and [`DEPLOY.md`](DEPLOY.md)
(why each free service was chosen, and how to move to Oracle later).
