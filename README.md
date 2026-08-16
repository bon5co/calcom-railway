# calcom-railway

Wrapper image for deploying [Cal.com](https://github.com/calcom/cal.diy) on
[Railway](https://railway.com), published as `ghcr.io/bon5co/calcom-railway`.

Upstream publishes exactly one image (`calcom/cal.com`) and it creates no user account.
Cal.com's `POST /api/auth/setup` has no authentication of its own — its only gate is
`prisma.user.count() !== 0` — so on a stock deploy the first visitor to reach the public URL
becomes the instance `ADMIN`, and the deployer is then locked out permanently
(`400 "No setup needed."`), with no password reset path that works without SMTP.

What this image changes:

- **Seeds the administrator before the HTTP server binds.** `scripts/seed-admin.ts` runs
  after `prisma migrate deploy` and before `next start`, using upstream's own
  `hashPassword`, so the first request the public domain ever serves already meets a
  claimed instance.
- **Re-applies the password on every boot.** A redeploy with a changed
  `CALCOM_ADMIN_PASSWORD` is a working password reset.
- **Refuses to boot** on an empty `CALCOM_ADMIN_EMAIL`, `CALCOM_ADMIN_PASSWORD` or
  `NEXT_PUBLIC_WEBAPP_URL`, and on a password shorter than the 15 characters Cal.com
  requires.
- **Closes public signup** (`NEXT_PUBLIC_DISABLE_SIGNUP=true`), which the stock image leaves
  open: a public Cal.com URL is otherwise a public sign-up page on the deployer's bill.
- **Honours the platform's `$PORT`.** Turborepo 2 defaults to strict env mode and `PORT` is
  not in cal.com's `turbo.json` `globalEnv`, so `yarn start` drops it and `next start`
  always binds 3000. The entrypoint runs the same task with `--env-mode=loose`.
- **Pins the upstream tag** (`v6.2.0`) on an app that migrates its database forward on boot.

## Environment

| Variable | Required | Notes |
| --- | --- | --- |
| `CALCOM_ADMIN_EMAIL` | yes | Administrator login. |
| `CALCOM_ADMIN_PASSWORD` | yes | Minimum 15 characters, mixed case and a number. |
| `CALCOM_ADMIN_USERNAME` | no | Defaults to `admin`. |
| `NEXT_PUBLIC_WEBAPP_URL` | yes | Public origin of the deployment. |
| `DATABASE_URL` / `DATABASE_DIRECT_URL` | yes | PostgreSQL connection strings. |
| `DATABASE_HOST` | no | `host:port` to wait for before migrating. |
| `NEXTAUTH_SECRET`, `CALENDSO_ENCRYPTION_KEY` | yes | 32-character secrets. |
