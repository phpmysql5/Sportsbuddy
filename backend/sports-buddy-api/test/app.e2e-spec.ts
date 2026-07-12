import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';
import { PrismaService } from '../src/database/prisma.service';

type AuthResponseBody = {
  accessToken: string;
  refreshToken: string;
  user: {
    email: string;
  };
};

type PublicUserBody = {
  email: string;
};

type SuggestionBody = {
  user: { email: string };
  reasons: string[];
  score: number;
};

function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null) {
    throw new Error('Expected object response body');
  }
  return value as Record<string, unknown>;
}

function readString(record: Record<string, unknown>, key: string): string {
  const value = record[key];
  if (typeof value !== 'string') {
    throw new Error(`Expected string field: ${key}`);
  }
  return value;
}

function toAuthResponseBody(body: unknown): AuthResponseBody {
  const record = asRecord(body);
  const userRecord = asRecord(record.user);

  return {
    accessToken: readString(record, 'accessToken'),
    refreshToken: readString(record, 'refreshToken'),
    user: {
      email: readString(userRecord, 'email'),
    },
  };
}

function toPublicUserBody(body: unknown): PublicUserBody {
  const record = asRecord(body);
  return {
    email: readString(record, 'email'),
  };
}

function toSuggestionsBody(body: unknown): SuggestionBody[] {
  if (!Array.isArray(body)) {
    throw new Error('Expected suggestions array');
  }

  return body.map((item) => {
    const record = asRecord(item);
    const userRecord = asRecord(record.user);
    const rawReasons = record.reasons;

    if (
      !Array.isArray(rawReasons) ||
      !rawReasons.every((r) => typeof r === 'string')
    ) {
      throw new Error('Expected string array: reasons');
    }

    const score = record.score;
    if (typeof score !== 'number') {
      throw new Error('Expected numeric field: score');
    }

    return {
      user: {
        email: readString(userRecord, 'email'),
      },
      reasons: rawReasons,
      score,
    };
  });
}

describe('Sports Buddy API (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaService;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    prisma = app.get(PrismaService);
    await app.init();
  });

  beforeEach(async () => {
    await prisma.user.deleteMany({
      where: { email: { endsWith: '@e2e.sportsbuddy.dev' } },
    });
  });

  it('/health (GET)', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect({ status: 'ok' });
  });

  it('registers, authenticates, refreshes, and revokes tokens', async () => {
    const email = `auth-${Date.now()}@e2e.sportsbuddy.dev`;
    const password = 'Password123!';

    const registerResponse = await request(app.getHttpServer())
      .post('/auth/register')
      .send({
        name: 'E2E Auth User',
        email,
        password,
      })
      .expect(201);
    const registerBody = toAuthResponseBody(registerResponse.body);

    expect(registerBody.user.email).toBe(email);
    expect(registerBody.accessToken.length).toBeGreaterThan(10);
    expect(registerBody.refreshToken.length).toBeGreaterThan(10);

    const meResponse = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${registerBody.accessToken}`)
      .expect(200);
    const meBody = toPublicUserBody(meResponse.body);

    expect(meBody.email).toBe(email);

    const refreshResponse = await request(app.getHttpServer())
      .post('/auth/refresh')
      .send({ refreshToken: registerBody.refreshToken })
      .expect(201);
    const refreshBody = toAuthResponseBody({
      ...refreshResponse.body,
      user: { email },
    });

    expect(refreshBody.accessToken.length).toBeGreaterThan(10);
    expect(refreshBody.refreshToken.length).toBeGreaterThan(10);

    await request(app.getHttpServer())
      .post('/auth/logout')
      .set('Authorization', `Bearer ${refreshBody.accessToken}`)
      .expect(201)
      .expect({ success: true });

    await request(app.getHttpServer())
      .post('/auth/refresh')
      .send({ refreshToken: refreshBody.refreshToken })
      .expect(401);
  });

  it('updates profile and returns compatible suggestions', async () => {
    const unique = Date.now().toString();
    const city = `E2ECity-${unique}`;
    const sport = `E2ESport-${unique}`;

    const userAEmail = `match-a-${unique}@e2e.sportsbuddy.dev`;
    const userBEmail = `match-b-${unique}@e2e.sportsbuddy.dev`;
    const password = 'Password123!';

    const userARegister = await request(app.getHttpServer())
      .post('/auth/register')
      .send({
        name: 'E2E Match User A',
        email: userAEmail,
        password,
      })
      .expect(201);
    const userABody = toAuthResponseBody(userARegister.body);

    const userBRegister = await request(app.getHttpServer())
      .post('/auth/register')
      .send({
        name: 'E2E Match User B',
        email: userBEmail,
        password,
      })
      .expect(201);
    const userBBody = toAuthResponseBody(userBRegister.body);

    await request(app.getHttpServer())
      .put('/profile')
      .set('Authorization', `Bearer ${userABody.accessToken}`)
      .send({
        city,
        sport,
        skillLevel: 'beginner',
        availabilityDays: ['Sat', 'Sun'],
      })
      .expect(200);

    await request(app.getHttpServer())
      .put('/profile')
      .set('Authorization', `Bearer ${userBBody.accessToken}`)
      .send({
        city,
        sport,
        skillLevel: 'intermediate',
        availabilityDays: ['Fri', 'Sat'],
      })
      .expect(200);

    const suggestionsResponse = await request(app.getHttpServer())
      .get('/matching/suggestions')
      .set('Authorization', `Bearer ${userABody.accessToken}`)
      .expect(200);
    const suggestions = toSuggestionsBody(suggestionsResponse.body);

    const buddy = suggestions.find((item) => item.user.email === userBEmail);

    expect(buddy).toBeDefined();
    expect(buddy?.score).toBeGreaterThanOrEqual(3);
    expect(buddy?.reasons).toEqual(
      expect.arrayContaining([
        'Same city',
        'Same sport',
        'Shared availability',
      ]),
    );
  });

  afterAll(async () => {
    await prisma.user.deleteMany({
      where: { email: { endsWith: '@e2e.sportsbuddy.dev' } },
    });
    await app.close();
  });
});
