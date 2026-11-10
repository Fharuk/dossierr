// Applies prisma/migrations/*/migration.sql to the PostgreSQL database in
// DATABASE_URL, and records them in _prisma_migrations the way
// `prisma migrate deploy` does.
//
// Why not the CLI: it wants the native schema-engine binary, which lives on
// binaries.prisma.sh, a host this sandbox can't reach. The SQL files are the
// same ones it would run (they're what the Docker image runs).
import { readdirSync, readFileSync } from "node:fs";
import { createHash, randomUUID } from "node:crypto";
import { join } from "node:path";
import pg from "pg";

const dir = "prisma/migrations";
const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
await client.connect();

await client.query(`CREATE TABLE IF NOT EXISTS "_prisma_migrations" (
  "id" varchar(36) PRIMARY KEY NOT NULL,
  "checksum" varchar(64) NOT NULL,
  "finished_at" timestamptz,
  "migration_name" varchar(255) NOT NULL,
  "logs" text,
  "rolled_back_at" timestamptz,
  "started_at" timestamptz NOT NULL DEFAULT now(),
  "applied_steps_count" integer NOT NULL DEFAULT 0
)`);

const { rows } = await client.query(`SELECT migration_name FROM "_prisma_migrations"`);
const applied = new Set(rows.map((row) => row.migration_name));

for (const name of readdirSync(dir).filter((entry) => /^\d/.test(entry)).sort()) {
  if (applied.has(name)) {
    console.log("skip   ", name);
    continue;
  }
  const sql = readFileSync(join(dir, name, "migration.sql"), "utf8");
  const checksum = createHash("sha256").update(sql).digest("hex");
  const id = randomUUID();
  await client.query(
    `INSERT INTO "_prisma_migrations" (id, checksum, migration_name, applied_steps_count) VALUES ($1, $2, $3, 0)`,
    [id, checksum, name],
  );
  try {
    await client.query("BEGIN");
    await client.query(sql);
    await client.query(
      `UPDATE "_prisma_migrations" SET finished_at = now(), applied_steps_count = 1 WHERE id = $1`,
      [id],
    );
    await client.query("COMMIT");
    console.log("applied", name);
  } catch (error) {
    await client.query("ROLLBACK");
    console.error(`failed ${name}: ${error.message}`);
    process.exitCode = 1;
    break;
  }
}

await client.end();
