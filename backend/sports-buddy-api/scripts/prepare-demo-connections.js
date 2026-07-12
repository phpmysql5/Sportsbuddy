const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
  const emails = {
    arjun: 'arjun.mangalore@sportsbuddy.dev',
    neha: 'neha.mangalore@sportsbuddy.dev',
    rohan: 'rohan.mangalore@sportsbuddy.dev',
  };

  const users = await prisma.user.findMany({
    where: { email: { in: Object.values(emails) } },
    select: { id: true, email: true, name: true },
  });

  const map = Object.fromEntries(users.map((u) => [u.email, u]));
  if (!map[emails.arjun] || !map[emails.neha] || !map[emails.rohan]) {
    throw new Error('Required demo users not found. Run npm run seed:demo first.');
  }

  const arjunId = map[emails.arjun].id;
  const nehaId = map[emails.neha].id;
  const rohanId = map[emails.rohan].id;

  // Clear all pairwise requests among the demo trio for deterministic state.
  await prisma.connectionRequest.deleteMany({
    where: {
      senderId: { in: [arjunId, nehaId, rohanId] },
      receiverId: { in: [arjunId, nehaId, rohanId] },
    },
  });

  await prisma.connectionRequest.upsert({
    where: {
      senderId_receiverId: {
        senderId: arjunId,
        receiverId: nehaId,
      },
    },
    create: {
      senderId: arjunId,
      receiverId: nehaId,
      status: 'accepted',
    },
    update: {
      status: 'accepted',
    },
  });

  await prisma.connectionRequest.upsert({
    where: {
      senderId_receiverId: {
        senderId: arjunId,
        receiverId: rohanId,
      },
    },
    create: {
      senderId: arjunId,
      receiverId: rohanId,
      status: 'pending',
    },
    update: {
      status: 'pending',
    },
  });

  const arjunOutgoingPending = await prisma.connectionRequest.count({
    where: { senderId: arjunId, status: 'pending' },
  });

  const arjunToNeha = await prisma.connectionRequest.findUnique({
    where: {
      senderId_receiverId: {
        senderId: arjunId,
        receiverId: nehaId,
      },
    },
    select: { status: true },
  });

  const arjunToRohan = await prisma.connectionRequest.findUnique({
    where: {
      senderId_receiverId: {
        senderId: arjunId,
        receiverId: rohanId,
      },
    },
    select: { status: true },
  });

  const arjunBuddies = await prisma.connectionRequest.count({
    where: {
      status: 'accepted',
      OR: [{ senderId: arjunId }, { receiverId: arjunId }],
    },
  });

  const nehaIncomingPending = await prisma.connectionRequest.count({
    where: { receiverId: nehaId, status: 'pending' },
  });

  const rohanIncomingPending = await prisma.connectionRequest.count({
    where: { receiverId: rohanId, status: 'pending' },
  });

  console.log(JSON.stringify({
    arjunOutgoingPending,
    arjunBuddies,
    nehaIncomingPending,
    rohanIncomingPending,
    arjunToNehaStatus: arjunToNeha?.status ?? null,
    arjunToRohanStatus: arjunToRohan?.status ?? null,
    note: 'Expected for demo: Arjun<->Neha accepted, Arjun->Rohan pending',
  }, null, 2));
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
