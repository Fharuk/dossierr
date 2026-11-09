#!/bin/sh
# A PostgreSQL 16 server for Dossier, from the pypi `pgserver` wheel: there's no
# Docker here and the sandbox has no system postgres. Dossier's schema is
# written for PostgreSQL, and the app reaches it through `pg`, a pure-JS
# driver, so nothing native has to run inside Next.js.
#
#   sh scripts/local/db.sh            start it (creating the database once)
#   sh scripts/local/db.sh stop       stop it
#   sh scripts/local/db.sh psql "…"   run SQL against it
set -eu
cd "$(dirname "$0")/../.."

PGROOT=/home/user/.local/pgserver/pgserver/pginstall
DATA=$(pwd)/data/pgdata
LOG=$(pwd)/data/postgres.log
PGPORT=${PGPORT:-54329}
psql() { "$PGROOT/bin/psql" -h 127.0.0.1 -p "$PGPORT" -U postgres -d dossier "$@"; }

case "${1:-start}" in
  stop)
    "$PGROOT/bin/pg_ctl" -D "$DATA" -m fast stop 2>/dev/null || echo "PostgreSQL isn't running."
    exit 0
    ;;
  psql)
    shift
    psql -tAc "$1"
    exit 0
    ;;
esac

if [ ! -x "$PGROOT/bin/postgres" ]; then
  echo "PostgreSQL isn't installed; run scripts/local/setup.sh first." >&2
  exit 1
fi

# initdb refuses a data directory others can read.
if [ ! -f "$DATA/PG_VERSION" ]; then
  mkdir -p data
  "$PGROOT/bin/initdb" -D "$DATA" -U postgres --auth=trust --encoding=UTF8 --locale=C >/dev/null
fi
chmod 700 "$DATA"

if ! "$PGROOT/bin/pg_isready" -q -h 127.0.0.1 -p "$PGPORT"; then
  # -k /tmp: the socket goes somewhere writable; the app connects over TCP.
  "$PGROOT/bin/pg_ctl" -D "$DATA" -l "$LOG" \
    -o "-p $PGPORT -k /tmp -c listen_addresses=127.0.0.1" -w start >/dev/null
fi

if ! psql -tAc "select 1 from pg_database where datname='dossier'" 2>/dev/null | grep -q 1; then
  "$PGROOT/bin/createdb" -h 127.0.0.1 -p "$PGPORT" -U postgres dossier
fi
echo "PostgreSQL 16 on 127.0.0.1:$PGPORT, database dossier, data in data/pgdata"
