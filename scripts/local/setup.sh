#!/bin/sh
# Sets this checkout up to run Dossier natively, without Docker, on the machine
# Arena gives us. Docker isn't available here, so this does by hand what the
# image and DEVELOPMENT.md do:
#
#   Node 24          Dossier hashes the sign-in password with crypto.argon2,
#                    which Node 22 lacks. The image runs Node 24 (Dockerfile).
#   PostgreSQL 16    data/pgdata, from the pypi `pgserver` wheel (see db.sh).
#                    Its schema is the PostgreSQL one; better-sqlite3 was no
#                    option, because this Node aborts on finalizing a native
#                    Statement inside `next start`.
#   standalone       The production build (.next/standalone/server.js), the way
#                    the image runs it.
#
# Re-running is safe: it only fills in what's missing.
set -eu
cd "$(dirname "$0")/../.."

NODE_DIR=/home/user/.local/node24
PG_DIR=/home/user/.local/pgserver
YARN_VERSION=4.18.1
PGPORT=${PGPORT:-54329}

say() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

# 1. Node 24. This sandbox's Node 22.22 has no crypto.argon2; the pypi wheel
#    ships the official binary plus the headers node-gyp needs for native
#    modules, and downloading it needs no host we don't have.
if [ ! -x "$NODE_DIR/bin/node" ]; then
  say "Installing Node 24 into $NODE_DIR"
  mkdir -p /home/user/.local /tmp/nodewheel
  pip install --quiet --target /tmp/nodewheel --upgrade nodejs-wheel-binaries==24.19.0
  cp -a /tmp/nodewheel/nodejs_wheel "$NODE_DIR"
fi
export PATH="$NODE_DIR/bin:$PATH"
echo "Node: $(node -v) (crypto.argon2 is a $(node -e 'process.stdout.write(typeof require("node:crypto").argon2)'))"

# 2. PostgreSQL 16, likewise from pypi (pgserver bundles the server binaries).
if [ ! -x "$PG_DIR/pgserver/pginstall/bin/postgres" ]; then
  say "Installing PostgreSQL 16 into $PG_DIR"
  pip install --quiet --target "$PG_DIR" pgserver==0.1.4
fi
# pgserver's build leaves out contrib/citext, which the first migration asks
# for (Skill and Language names compare without case). scripts/local has the
# extension's SQL, with the handful of functions it declares in C written in
# SQL instead, so no shared library is needed.
PG_EXT="$PG_DIR/pgserver/pginstall/share/postgresql/extension"
cp scripts/local/citext.control "$PG_EXT/citext.control"
cp scripts/local/citext--1.4.sql "$PG_EXT/citext--1.4.sql"
cp scripts/local/citext--1.4.sql "$PG_EXT/citext--1.6.sql"

# 3. Yarn 4, the version package.json pins.
#    The corepack that comes with the pypi wheel has no lib/corepack.cjs, so
#    this uses the system one, and points it at the npm registry: the
#    repo.yarnpkg.com it would otherwise use isn't reachable from here.
if [ "$(yarn -v 2>/dev/null || true)" != "$YARN_VERSION" ]; then
  say "Activating Yarn $YARN_VERSION"
  COREPACK_HOME=/home/user/.cache/corepack \
  COREPACK_NPM_REGISTRY=https://registry.npmjs.org \
    /usr/local/bin/corepack prepare "yarn@$YARN_VERSION" --activate
fi
# That download lands in corepack's cache, not on PATH, and yarn 1 is still
# the `yarn` here: every call goes through the 4.18.1 release directly.
YARN="node /home/user/.cache/corepack/v1/yarn/$YARN_VERSION/yarn.js"
echo "Yarn: $($YARN -v)"

# 4. Dependencies. better-sqlite3 comes along as the SQLite adapter's peer;
#    building it needs the Node 24 headers above (prebuild-install can't verify
#    this sandbox's TLS certificate, so it compiles from source).
if [ ! -d node_modules/next ]; then
  say "Installing dependencies (a few minutes)"
  YARN_NPM_REGISTRY_SERVER=https://registry.npmjs.org \
  YARN_ENABLE_GLOBAL_CACHE=1 \
  npm_config_nodedir="$NODE_DIR" \
  npm_config_build_from_source=true \
    $YARN install
fi

# 5. .env: the password hash, the secret and the database URL. Kept as it is if
#    it's already there, so a restart doesn't sign you out or move the data.
if [ ! -f .env ]; then
  say "Writing .env"
  password=${DOSSIER_LOCAL_PASSWORD:-Dossier-Arena-2026}
  hash=$(printf '%s\n' "$password" | $YARN hash-password 2>/dev/null)
  mkdir -p data
  cat > .env <<EOF
# Local (no Docker) run: PostgreSQL in ./data/pgdata, one Node process.
# The password is kept as an argon2id hash. To change it, put a new one from
# hash-password here and restart.
DOSSIER_PASSWORD=$hash
DOSSIER_SECRET=$(openssl rand -base64 32)
DATABASE_URL="postgresql://postgres@127.0.0.1:$PGPORT/dossier"
DOSSIER_DATA_DIR=$PWD/data
DOSSIER_TELEMETRY=off
EOF
  echo "Sign in with: $password"
fi

# 6. Prisma clients. `prisma generate` looks for a native schema-engine binary
#    first, which lives on binaries.prisma.sh, a host we can't reach; the stub
#    keeps it from trying.
if [ ! -d src/generated/prisma ] || [ ! -d src/generated/prisma-sqlite ]; then
  say "Generating Prisma clients"
  printf '#!/bin/sh\nexit 0\n' > /tmp/prisma-engine-stub && chmod +x /tmp/prisma-engine-stub
  PRISMA_SCHEMA_ENGINE_BINARY=/tmp/prisma-engine-stub $YARN prisma generate --schema prisma/schema.prisma
  PRISMA_SCHEMA_ENGINE_BINARY=/tmp/prisma-engine-stub $YARN prisma generate
fi

# 7. The database: PostgreSQL up, migrations applied, built-in themes loaded.
say "Database"
PGPORT="$PGPORT" sh scripts/local/db.sh
set -a; . ./.env; set +a
if [ -z "$(PGPORT="$PGPORT" sh scripts/local/db.sh psql 'select 1 from "Theme" limit 1' 2>/dev/null || true)" ]; then
  node scripts/local/migrate-postgres.mjs
  ./node_modules/.bin/tsx prisma/seed.ts
fi

# 8. Production build, then the standalone layout next.config.ts asks for: the
#    server plus the files it serves, as the Dockerfile assembles them.
if [ ! -f .next/standalone/server.js ] || [ ! -d .next/standalone/public ]; then
  say "Building"
  # next.config.ts reads this while building (X-Frame-Options), hence here as
  # well as in serve.sh.
  export DOSSIER_ALLOW_EMBED=on
  $YARN build
  cp -a public .next/standalone/public
  cp -a .next/static .next/standalone/.next/static
fi

say "Ready: sh scripts/local/serve.sh"
