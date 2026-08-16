#!/bin/sh
# Railway entrypoint for Cal.com.
#
# Order matters: every step below finishes before Next.js binds a port, so the
# very first request the public Railway domain ever serves already meets a
# claimed instance. Upstream's own scripts/start.sh starts the server first and
# creates no user at all.
set -e
cd /calcom

if [ -z "${CALCOM_ADMIN_EMAIL}" ]; then
  echo "[railway] refusing to boot: CALCOM_ADMIN_EMAIL is empty." >&2
  exit 1
fi
if [ -z "${CALCOM_ADMIN_PASSWORD}" ]; then
  echo "[railway] refusing to boot: CALCOM_ADMIN_PASSWORD is empty." >&2
  echo "[railway] Cal.com's /api/auth/setup is unauthenticated; an instance with no" >&2
  echo "[railway] administrator is claimable by the first visitor." >&2
  exit 1
fi

if [ -z "${NEXT_PUBLIC_WEBAPP_URL}" ]; then
  echo "[railway] refusing to boot: NEXT_PUBLIC_WEBAPP_URL is empty." >&2
  exit 1
fi

# Cal.com derives the NextAuth callback origin from NEXTAUTH_URL when it is set.
export NEXTAUTH_URL="${NEXTAUTH_URL:-${NEXT_PUBLIC_WEBAPP_URL}}"

# The published image is built against http://localhost:3000 and rewrites the
# statically built copies of that origin at start-up.
scripts/replace-placeholder.sh "${BUILT_NEXT_PUBLIC_WEBAPP_URL}" "${NEXT_PUBLIC_WEBAPP_URL}"

if [ -n "${DATABASE_HOST}" ]; then
  scripts/wait-for-it.sh "${DATABASE_HOST}" --timeout=120 -- echo "[railway] database is up"
fi

npx prisma migrate deploy --schema /calcom/packages/prisma/schema.prisma
npx ts-node --transpile-only /calcom/scripts/seed-app-store.ts
npx ts-node --transpile-only /calcom/scripts/seed-admin.ts

echo "[railway] starting Cal.com on port ${PORT:-3000}"
# Turborepo 2 defaults to strict env mode, and PORT is not in cal.com's
# turbo.json globalEnv list — so `yarn start` (turbo run start) drops it and
# `next start` always binds 3000, whatever the platform injected. Railway's HTTP
# healthcheck dials the injected port, so the app has to honour it: --env-mode=loose
# passes the real environment through to the task.
exec yarn turbo run start --filter="@calcom/web" --env-mode=loose
