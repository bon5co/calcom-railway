/**
 * Seed (and re-seed) the Cal.com administrator from the environment.
 *
 * Cal.com ships no CLI and no seeding path for self-hosters: the only way to get
 * the first ADMIN account is POST /api/auth/setup, which is unauthenticated and
 * open to whoever reaches the URL first. This script does the same work the setup
 * route does, using upstream's own password hashing, but it runs before the HTTP
 * server binds and it is idempotent, so every redeploy re-applies the password
 * from the environment instead of leaving the account unrecoverable.
 */
import { hashPassword } from "@calcom/lib/auth/hashPassword";
import slugify from "@calcom/lib/slugify";
import prisma from "@calcom/prisma";
import { CreationSource, IdentityProvider } from "@calcom/prisma/enums";

async function main() {
  const email = (process.env.CALCOM_ADMIN_EMAIL || "").trim().toLowerCase();
  const password = (process.env.CALCOM_ADMIN_PASSWORD || "").trim();
  const username = slugify((process.env.CALCOM_ADMIN_USERNAME || "admin").trim());

  if (!email || !password) {
    console.error("[seed-admin] CALCOM_ADMIN_EMAIL and CALCOM_ADMIN_PASSWORD are both required.");
    process.exit(1);
  }
  if (password.length < 15) {
    console.error(
      `[seed-admin] CALCOM_ADMIN_PASSWORD is ${password.length} characters; Cal.com requires at least 15.`
    );
    process.exit(1);
  }

  const hash = await hashPassword(password);

  const user = await prisma.user.upsert({
    where: { email },
    update: {
      role: "ADMIN",
      emailVerified: new Date(),
      identityProvider: IdentityProvider.CAL,
    },
    create: {
      email,
      username,
      name: "Administrator",
      role: "ADMIN",
      emailVerified: new Date(),
      locale: "en",
      identityProvider: IdentityProvider.CAL,
      creationSource: CreationSource.WEBAPP,
    },
    select: { id: true, username: true },
  });

  await prisma.userPassword.upsert({
    where: { userId: user.id },
    update: { hash },
    create: { userId: user.id, hash },
  });

  const total = await prisma.user.count();
  console.log(
    `[seed-admin] administrator ready: ${email} (username=${user.username}, users_in_db=${total})`
  );
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (error) => {
    console.error("[seed-admin] failed:", error);
    await prisma.$disconnect();
    process.exit(1);
  });
