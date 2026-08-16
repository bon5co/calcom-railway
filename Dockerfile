# Cal.com for Railway — pinned, with the admin account seeded before the server binds.
#
# Upstream publishes exactly one image and it does not create any user. Cal.com's
# /api/auth/setup route has no authentication of its own: its only gate is
# `prisma.user.count() !== 0`, so on a stock deploy the first visitor to reach the
# public URL becomes the instance ADMIN and the deployer is locked out for good.
# This wrapper seeds the administrator from the environment before `yarn start`
# runs, closes public signup, and re-applies the password on every boot so a
# redeploy is a working password reset (upstream has no reset path that works
# without SMTP).
FROM calcom/cal.com:v6.2.0

ENV NEXT_PUBLIC_LICENSE_CONSENT=agree \
    NEXT_PUBLIC_DISABLE_SIGNUP=true \
    CALCOM_TELEMETRY_DISABLED=1 \
    NEXT_TELEMETRY_DISABLED=1 \
    TURBO_TELEMETRY_DISABLED=1 \
    CALCOM_ADMIN_USERNAME=admin

COPY scripts/seed-admin.ts /calcom/scripts/seed-admin.ts
COPY scripts/railway-entrypoint.sh /calcom/scripts/railway-entrypoint.sh
RUN chmod +x /calcom/scripts/railway-entrypoint.sh

ENTRYPOINT ["/calcom/scripts/railway-entrypoint.sh"]
CMD []
