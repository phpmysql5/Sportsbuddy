import * as argon2 from 'argon2';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';
import { PrismaClient } from '@prisma/client';

type DemoUserSeed = {
  email: string;
  name: string;
  city: string;
  sport: string;
  skillLevel: 'beginner' | 'intermediate' | 'advanced';
  availabilityDays: string[];
};

const DEMO_PASSWORD = 'Demo@1234';

const DEMO_USERS: DemoUserSeed[] = [
  {
    email: 'ava.tennis@sportsbuddy.dev',
    name: 'Ava Patel',
    city: 'Bengaluru',
    sport: 'Tennis',
    skillLevel: 'intermediate',
    availabilityDays: ['Mon', 'Wed', 'Sat'],
  },
  {
    email: 'ryan.tennis@sportsbuddy.dev',
    name: 'Ryan Mehta',
    city: 'Bengaluru',
    sport: 'Tennis',
    skillLevel: 'intermediate',
    availabilityDays: ['Wed', 'Fri', 'Sat'],
  },
  {
    email: 'maya.badminton@sportsbuddy.dev',
    name: 'Maya Reddy',
    city: 'Bengaluru',
    sport: 'Badminton',
    skillLevel: 'advanced',
    availabilityDays: ['Tue', 'Thu', 'Sun'],
  },
  {
    email: 'noah.cricket@sportsbuddy.dev',
    name: 'Noah Sharma',
    city: 'Hyderabad',
    sport: 'Cricket',
    skillLevel: 'beginner',
    availabilityDays: ['Sat', 'Sun'],
  },
  {
    email: 'sara.tennis@sportsbuddy.dev',
    name: 'Sara Iyer',
    city: 'Bengaluru',
    sport: 'Tennis',
    skillLevel: 'advanced',
    availabilityDays: ['Mon', 'Thu', 'Sat'],
  },
  {
    email: 'arjun.mangalore@sportsbuddy.dev',
    name: 'Arjun Dsouza',
    city: 'Mangalore',
    sport: 'Tennis',
    skillLevel: 'beginner',
    availabilityDays: ['Sat', 'Sun'],
  },
  {
    email: 'neha.mangalore@sportsbuddy.dev',
    name: 'Neha Shetty',
    city: 'Mangalore',
    sport: 'Tennis',
    skillLevel: 'intermediate',
    availabilityDays: ['Fri', 'Sat'],
  },
  {
    email: 'rohan.mangalore@sportsbuddy.dev',
    name: 'Rohan Pinto',
    city: 'Mangalore',
    sport: 'Tennis',
    skillLevel: 'beginner',
    availabilityDays: ['Thu', 'Sat'],
  },
];

function loadDatabaseUrlFromEnvFile(): void {
  if (process.env.DATABASE_URL && process.env.DATABASE_URL.trim().length > 0) {
    return;
  }

  const envPath = resolve(process.cwd(), '.env');
  if (!existsSync(envPath)) {
    return;
  }

  const content = readFileSync(envPath, 'utf8');
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) {
      continue;
    }

    const separatorIndex = line.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }

    const key = line.slice(0, separatorIndex).trim();
    let value = line.slice(separatorIndex + 1).trim();

    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

async function main() {
  loadDatabaseUrlFromEnvFile();

  if (!process.env.DATABASE_URL) {
    throw new Error(
      'DATABASE_URL is not set. Define it in environment or backend/sports-buddy-api/.env.',
    );
  }

  const prisma = new PrismaClient();

  try {
    const passwordHash = await argon2.hash(DEMO_PASSWORD);

    for (const user of DEMO_USERS) {
      await prisma.user.upsert({
        where: { email: user.email },
        update: {
          name: user.name,
          city: user.city,
          sport: user.sport,
          skillLevel: user.skillLevel,
          availabilityDays: user.availabilityDays,
          passwordHash,
          refreshTokenHash: null,
        },
        create: {
          email: user.email,
          name: user.name,
          city: user.city,
          sport: user.sport,
          skillLevel: user.skillLevel,
          availabilityDays: user.availabilityDays,
          passwordHash,
        },
      });
    }

    console.log(`Seeded ${DEMO_USERS.length} demo users.`);
    console.log(`Demo password for all seeded users: ${DEMO_PASSWORD}`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error('Demo seed failed:', error);
  process.exit(1);
});
