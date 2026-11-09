#!/bin/sh
# Runs Dossier on 0.0.0.0:${PORT:-3000} from this checkout: PostgreSQL, then the
# standalone server, as the Docker image runs it (see scripts/local/setup.sh).
set -eu
cd "$(dirname "$0")/../.."

export PATH="/home/user/.local/node24/bin:$PATH"

# Arena's live preview shows the app in an iframe on another origin; this drops
# frame-ancestors/X-Frame-Options so it can (see src/lib/csp.ts).
export DOSSIER_ALLOW_EMBED=on

set -a
. ./.env
set +a

sh scripts/local/db.sh

# The standalone server takes the port and hostname from these.
export PORT="${PORT:-3000}"
export HOSTNAME=0.0.0.0
# Its working directory is .next/standalone, so give it absolute paths.
export DOSSIER_DATA_DIR="$PWD/data"
mkdir -p "$DOSSIER_DATA_DIR"

cd .next/standalone
exec node server.js
