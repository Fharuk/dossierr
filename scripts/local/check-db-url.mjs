// Checks a Postgres connection string for the mistakes that are easy to make
// when copying one out of a browser: markdown links around it, an escaped
// ampersand, stray spaces, a missing sslmode, a pooler in the wrong place.
//
// It never prints the password. With --connect it also opens a connection
// (one round trip, then it closes), which is the only real test.
//
//   node scripts/local/check-db-url.mjs '<url>'
//   node scripts/local/check-db-url.mjs --connect "$DATABASE_URL"

import { redact } from "./redact.mjs";

const args = process.argv.slice(2);
const connect = args.includes("--connect");
const input = args.find((arg) => !arg.startsWith("--"));

if (!input) {
  console.error("usage: node scripts/local/check-db-url.mjs [--connect] '<postgres url>'");
  process.exit(2);
}

const problems = [];
const notes = [];

/** The string as a shell or a chat client may have mangled it. */
function tidy(raw) {
  let url = raw.trim();

  if (url.includes("&amp;")) {
    problems.push("The string contains `&amp;` — that's HTML-escaped `&`. It must be a plain `&`.");
    url = url.replaceAll("&amp;", "&");
  }

  // "[url](mailto:url)" or "[url](https://host)" around the whole address: the
  // link text is the address; the target is the same thing made clickable.
  const wrapped = /^\[([^\]]+)\]\(([^)]+)\)$/.exec(url);
  if (wrapped) {
    const [, text, target] = wrapped;
    problems.push(
      "The string is wrapped in a markdown link, `[…]](mailto:…)`. Take only the address, not the link.",
    );
    // Whichever half is the postgres URL; the other is its mailto:/https: twin.
    url = /^postgres(ql)?:\/\//.test(text) ? text : target.replace(/^mailto:/, "");
  } else if (/\[|\]|\(mailto:\)/.test(url)) {
    problems.push("The string still contains `[`, `]` or `mailto:` — a chat client made it a link. Use the plain address.");
    url = url.replace(/^\[/, "").replace(/\]\(([^)]*)\)$/, "").replace(/^mailto:/, "");
  }

  if (/^postgres(ql)?:\s/.test(url) || /\s/.test(url.replace(/^\s+|\s+$/g, ""))) {
    problems.push("There's a space inside the string — usually a copied line break.");
    url = url.replace(/\s+/g, "");
  }

  return url;
}

const url = tidy(input);
const shown = redact(url);

let parsed;
try {
  parsed = new URL(url);
} catch {
  console.error(`Not a URL at all: ${shown}`);
  process.exit(1);
}

if (!["postgres:", "postgresql:"].includes(parsed.protocol)) {
  problems.push(`Scheme is "${parsed.protocol}" — it should be postgresql://.`);
}
if (!parsed.username) problems.push("No user name before the ':'. Neon's is usually neondb_owner.");
if (!parsed.password) problems.push("No password between ':' and '@'.");
if (!parsed.hostname) problems.push("No host after '@'.");
if (!parsed.pathname || parsed.pathname === "/") problems.push("No database name after the host (e.g. /neondb).");

const params = parsed.searchParams;
const sslmode = params.get("sslmode");
if (!sslmode) problems.push("No sslmode. Neon needs ?sslmode=require (the Connect dialog includes it).");
else if (!["require", "verify-full"].includes(sslmode)) notes.push(`sslmode=${sslmode} — Neon expects require.`);

const isNeon = /\.neon\.tech$/i.test(parsed.hostname);
const pooled = parsed.hostname.includes("-pooler");
const region = /\.([a-z0-9-]+)\.aws\.neon\.tech$/i.exec(parsed.hostname)?.[1] ?? null;

if (isNeon && !pooled) {
  notes.push(
    "No `-pooler` in the host: this is Neon's direct address. Use it for DIRECT_URL (migrations), and the pooled one for DATABASE_URL.",
  );
}
if (params.get("channel_binding")) {
  notes.push(`channel_binding=${params.get("channel_binding")} is fine for Dossier's driver (pg 8) — it's ignored there, not rejected.`);
}

console.log("Host:      " + parsed.hostname);
console.log("User:      " + parsed.username);
console.log("Password:  " + "*".repeat(Math.min(12, decodedLength(parsed.password))) + ` (${decodedLength(parsed.password)} characters)`);
console.log("Database:  " + parsed.pathname.slice(1));
console.log("Pooled:    " + (pooled ? "yes" : "no"));
if (region) console.log("Neon region: " + region);
console.log("As given:  " + shown);

if (problems.length) {
  console.log("\nProblems:");
  for (const problem of problems) console.log("  ✗ " + problem);
} else {
  console.log("\nSyntax:    ok — nothing wrong with the shape of the string.");
}
if (notes.length) {
  console.log("\nWorth knowing:");
  for (const note of notes) console.log("  · " + note);
}

if (connect && !problems.length) {
  const { default: pg } = await import("../../node_modules/pg/lib/index.js");
  const client = new pg.Client({
    connectionString: url,
    connectionTimeoutMillis: 15000,
    ssl: sslmode && sslmode !== "disable" ? { rejectUnauthorized: sslmode === "verify-full" } : undefined,
  });
  try {
    await client.connect();
    const { rows } = await client.query("select current_database() as db, split_part(version(), ' ', 2) as version");
    const { rows: tables } = await client.query(
      "select count(*)::int as n from information_schema.tables where table_schema = 'public'",
    );
    console.log(`\nConnected: yes — ${rows[0].db}, Postgres ${rows[0].version}, ${tables[0].n} tables in public.`);
    if (tables[0].n === 0) console.log("  (empty: Dossier creates its tables on first start)");
  } catch (error) {
    console.log("\nConnected: no — " + redact(String(error.message)));
    console.log("  password authentication failed → reset it in Neon (Connect → Reset password), copy again");
    console.log("  could not translate host / timeout → the project or compute is gone, or your network blocks 5432");
  } finally {
    await client.end().catch(() => {});
  }
}

/** The password's length once percent-encoding is undone. */
function decodedLength(raw) {
  try {
    return decodeURIComponent(raw).length;
  } catch {
    return raw.length;
  }
}

if (problems.length) process.exitCode = 1;
