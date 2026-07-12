import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import type { Response } from 'superagent';
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

type ConnectionRequestBody = {
  id: string;
  status: string;
};

type ReportResponseBody = {
  success: boolean;
  reportId: string;
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

function toConnectionRequestBody(body: unknown): ConnectionRequestBody {
  const record = asRecord(body);
  return {
    id: readString(record, 'id'),
    status: readString(record, 'status'),
  };
}

function toRecordArray(body: unknown): Record<string, unknown>[] {
  if (!Array.isArray(body)) {
    throw new Error('Expected array response body');
  }

  return body.map((entry) => asRecord(entry));
}

function toReportResponseBody(body: unknown): ReportResponseBody {
  const record = asRecord(body);
  const success = record.success;
  if (typeof success !== 'boolean') {
    throw new Error('Expected boolean field: success');
  }

  return {
    success,
    reportId: readString(record, 'reportId'),
  };
}

async function registerUser(
  app: INestApplication<App>,
  { name, email, password }: { name: string; email: string; password: string },
): Promise<AuthResponseBody> {
  const response = await request(app.getHttpServer())
    .post('/auth/register')
    .send({ name, email, password })
    .expect(201);

  return toAuthResponseBody(response.body);
}

describe('Sports Buddy API (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaService;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
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

  it('rejects duplicate registration for same email', async () => {
    const email = `dup-${Date.now()}@e2e.sportsbuddy.dev`;
    const password = 'Password123!';

    await registerUser(app, {
      name: 'E2E Duplicate User',
      email,
      password,
    });

    const duplicateResponse = await request(app.getHttpServer())
      .post('/auth/register')
      .send({
        name: 'Another User',
        email,
        password,
      })
      .expect(400);

    const duplicateBody = asRecord(duplicateResponse.body);
    expect(readString(duplicateBody, 'message')).toContain(
      'Email is already registered',
    );
  });

  it('handles concurrent duplicate registration safely', async () => {
    const email = `concurrent-${Date.now()}@e2e.sportsbuddy.dev`;
    const password = 'Password123!';

    const results = await Promise.allSettled([
      request(app.getHttpServer()).post('/auth/register').send({
        name: 'Concurrent User A',
        email,
        password,
      }),
      request(app.getHttpServer()).post('/auth/register').send({
        name: 'Concurrent User B',
        email,
        password,
      }),
    ]);

    const fulfilled = results
      .filter(
        (r): r is PromiseFulfilledResult<Response> => r.status === 'fulfilled',
      )
      .map((r) => r.value.status)
      .sort((a, b) => a - b);

    expect(fulfilled).toEqual([201, 400]);
  });

  it('rejects login with wrong password', async () => {
    const email = `login-${Date.now()}@e2e.sportsbuddy.dev`;
    const password = 'Password123!';

    await registerUser(app, {
      name: 'E2E Login User',
      email,
      password,
    });

    await request(app.getHttpServer())
      .post('/auth/login')
      .send({ email, password: 'WrongPassword123!' })
      .expect(401);
  });

  it('blocks protected endpoints without access token', async () => {
    await request(app.getHttpServer()).get('/auth/me').expect(401);
    await request(app.getHttpServer()).get('/matching/suggestions').expect(401);
    await request(app.getHttpServer())
      .put('/profile')
      .send({
        city: 'Mangalore',
        sport: 'Tennis',
        skillLevel: 'beginner',
        availabilityDays: ['Sat'],
      })
      .expect(401);
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
    const alternateSport = `E2EAltSport-${unique}`;

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
        sports: [sport, alternateSport],
        skillLevel: 'beginner',
        availabilityDays: ['Sat', 'Sun'],
      })
      .expect(200);

    await request(app.getHttpServer())
      .put('/profile')
      .set('Authorization', `Bearer ${userBBody.accessToken}`)
      .send({
        city,
        sports: [sport],
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

  it('rejects invalid profile payload', async () => {
    const email = `bad-profile-${Date.now()}@e2e.sportsbuddy.dev`;
    const password = 'Password123!';

    const authBody = await registerUser(app, {
      name: 'E2E Bad Profile User',
      email,
      password,
    });

    await request(app.getHttpServer())
      .put('/profile')
      .set('Authorization', `Bearer ${authBody.accessToken}`)
      .send({
        city: 'A',
        sport: 'B',
        skillLevel: 'expert',
        availabilityDays: ['Mon'],
      })
      .expect(400);
  });

  it('returns no suggestions for incompatible city/sport', async () => {
    const unique = Date.now().toString();
    const password = 'Password123!';

    const userA = await registerUser(app, {
      name: 'E2E No Match A',
      email: `nomatch-a-${unique}@e2e.sportsbuddy.dev`,
      password,
    });

    const userB = await registerUser(app, {
      name: 'E2E No Match B',
      email: `nomatch-b-${unique}@e2e.sportsbuddy.dev`,
      password,
    });

    await request(app.getHttpServer())
      .put('/profile')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({
        city: 'CityOne',
        sports: ['Tennis'],
        skillLevel: 'intermediate',
        availabilityDays: ['Sat'],
      })
      .expect(200);

    await request(app.getHttpServer())
      .put('/profile')
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .send({
        city: 'CityTwo',
        sports: ['Cricket'],
        skillLevel: 'intermediate',
        availabilityDays: ['Sat'],
      })
      .expect(200);

    const suggestionsResponse = await request(app.getHttpServer())
      .get('/matching/suggestions')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200);

    const suggestions = toSuggestionsBody(suggestionsResponse.body);
    expect(suggestions).toHaveLength(0);
  });

  it('matches users with case-insensitive city and sport values', async () => {
    const unique = Date.now().toString();
    const password = 'Password123!';

    const userA = await registerUser(app, {
      name: 'Case Match A',
      email: `case-a-${unique}@e2e.sportsbuddy.dev`,
      password,
    });

    const userB = await registerUser(app, {
      name: 'Case Match B',
      email: `case-b-${unique}@e2e.sportsbuddy.dev`,
      password,
    });

    await request(app.getHttpServer())
      .put('/profile')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({
        city: 'Mangalore',
        sports: ['TENNIS'],
        skillLevel: 'beginner',
        availabilityDays: ['Sat'],
      })
      .expect(200);

    await request(app.getHttpServer())
      .put('/profile')
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .send({
        city: 'mangalore',
        sports: ['tennis'],
        skillLevel: 'intermediate',
        availabilityDays: ['Sat'],
      })
      .expect(200);

    const suggestionsResponse = await request(app.getHttpServer())
      .get('/matching/suggestions')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200);

    const suggestions = toSuggestionsBody(suggestionsResponse.body);
    const buddy = suggestions.find(
      (candidate) =>
        candidate.user.email === `case-b-${unique}@e2e.sportsbuddy.dev`,
    );

    expect(buddy).toBeDefined();
  });

  it('sends, accepts, and lists connected buddies', async () => {
    const unique = Date.now().toString();
    const password = 'Password123!';

    const userA = await registerUser(app, {
      name: 'Request Sender',
      email: `request-a-${unique}@e2e.sportsbuddy.dev`,
      password,
    });
    const userB = await registerUser(app, {
      name: 'Request Receiver',
      email: `request-b-${unique}@e2e.sportsbuddy.dev`,
      password,
    });

    const senderMe = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200);
    const sender = toPublicUserBody(senderMe.body);

    const receiverMe = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .expect(200);
    const receiverRecord = asRecord(receiverMe.body);
    const receiverId = readString(receiverRecord, 'id');

    const sendResponse = await request(app.getHttpServer())
      .post('/connections/requests')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({ receiverId })
      .expect(201);

    const sentRequest = toConnectionRequestBody(sendResponse.body);
    expect(sentRequest.status).toBe('pending');

    const incoming = await request(app.getHttpServer())
      .get('/connections/requests/incoming')
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .expect(200);

    const incomingList = toRecordArray(incoming.body);
    expect(incomingList.length).toBe(1);

    const respondResponse = await request(app.getHttpServer())
      .post(`/connections/requests/${sentRequest.id}/respond`)
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .send({ action: 'accept' })
      .expect(201);

    const responded = toConnectionRequestBody(respondResponse.body);
    expect(responded.status).toBe('accepted');

    const senderBuddies = await request(app.getHttpServer())
      .get('/connections/buddies')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200);

    const senderBuddiesList = toRecordArray(senderBuddies.body);
    expect(senderBuddiesList.length).toBe(1);
    expect(readString(senderBuddiesList[0], 'email')).toBe(
      `request-b-${unique}@e2e.sportsbuddy.dev`,
    );

    expect(sender.email).toBe(`request-a-${unique}@e2e.sportsbuddy.dev`);
  });

  it('cancels outgoing request and removes connected buddy', async () => {
    const unique = Date.now().toString();
    const password = 'Password123!';

    const userA = await registerUser(app, {
      name: 'Lifecycle User A',
      email: `lifecycle-a-${unique}@e2e.sportsbuddy.dev`,
      password,
    });
    const userB = await registerUser(app, {
      name: 'Lifecycle User B',
      email: `lifecycle-b-${unique}@e2e.sportsbuddy.dev`,
      password,
    });

    const receiverMe = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .expect(200);
    const receiverRecord = asRecord(receiverMe.body);
    const receiverId = readString(receiverRecord, 'id');

    const sendResponse = await request(app.getHttpServer())
      .post('/connections/requests')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({ receiverId })
      .expect(201);
    const sentRequest = toConnectionRequestBody(sendResponse.body);

    await request(app.getHttpServer())
      .delete(`/connections/requests/${sentRequest.id}`)
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200)
      .expect({ success: true });

    const outgoingAfterCancel = await request(app.getHttpServer())
      .get('/connections/requests/outgoing')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200);
    expect(toRecordArray(outgoingAfterCancel.body)).toHaveLength(0);

    const sendAgain = await request(app.getHttpServer())
      .post('/connections/requests')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({ receiverId })
      .expect(201);
    const pendingAgain = toConnectionRequestBody(sendAgain.body);

    await request(app.getHttpServer())
      .post(`/connections/requests/${pendingAgain.id}/respond`)
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .send({ action: 'accept' })
      .expect(201);

    const buddiesBeforeRemove = await request(app.getHttpServer())
      .get('/connections/buddies')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200);
    const buddyList = toRecordArray(buddiesBeforeRemove.body);
    expect(buddyList).toHaveLength(1);
    const buddyId = readString(buddyList[0], 'id');

    await request(app.getHttpServer())
      .delete(`/connections/buddies/${buddyId}`)
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200)
      .expect({ success: true });

    const buddiesAfterRemoveA = await request(app.getHttpServer())
      .get('/connections/buddies')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200);
    expect(toRecordArray(buddiesAfterRemoveA.body)).toHaveLength(0);

    const buddiesAfterRemoveB = await request(app.getHttpServer())
      .get('/connections/buddies')
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .expect(200);
    expect(toRecordArray(buddiesAfterRemoveB.body)).toHaveLength(0);
  });

  it('blocks users from suggestions and restores visibility after unblock', async () => {
    const unique = Date.now().toString();
    const password = 'Password123!';

    const userA = await registerUser(app, {
      name: 'Safety A',
      email: `safety-a-${unique}@e2e.sportsbuddy.dev`,
      password,
    });
    const userB = await registerUser(app, {
      name: 'Safety B',
      email: `safety-b-${unique}@e2e.sportsbuddy.dev`,
      password,
    });

    const userAMe = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200);
    const userAId = readString(asRecord(userAMe.body), 'id');

    const userBMe = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .expect(200);
    const userBId = readString(asRecord(userBMe.body), 'id');

    await request(app.getHttpServer())
      .put('/profile')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({
        city: 'Safety City',
        sports: ['Badminton'],
        skillLevel: 'beginner',
        availabilityDays: ['Sat'],
      })
      .expect(200);

    await request(app.getHttpServer())
      .put('/profile')
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .send({
        city: 'Safety City',
        sports: ['Badminton'],
        skillLevel: 'beginner',
        availabilityDays: ['Sat'],
      })
      .expect(200);

    const beforeBlock = await request(app.getHttpServer())
      .get('/matching/suggestions')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200);
    const beforeBlockSuggestions = toSuggestionsBody(beforeBlock.body);
    expect(
      beforeBlockSuggestions.some(
        (candidate) =>
          candidate.user.email === `safety-b-${unique}@e2e.sportsbuddy.dev`,
      ),
    ).toBe(true);

    await request(app.getHttpServer())
      .post('/safety/blocks')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({ userId: userBId })
      .expect(201)
      .expect({ success: true });

    const blockedList = await request(app.getHttpServer())
      .get('/safety/blocks')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200);
    const blockedEntries = toRecordArray(blockedList.body);
    expect(blockedEntries).toHaveLength(1);
    expect(readString(blockedEntries[0], 'id')).toBe(userBId);

    const afterBlockA = await request(app.getHttpServer())
      .get('/matching/suggestions')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200);
    expect(toSuggestionsBody(afterBlockA.body)).toHaveLength(0);

    const afterBlockB = await request(app.getHttpServer())
      .get('/matching/suggestions')
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .expect(200);
    expect(toSuggestionsBody(afterBlockB.body)).toHaveLength(0);

    await request(app.getHttpServer())
      .delete(`/safety/blocks/${userBId}`)
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200)
      .expect({ success: true });

    const afterUnblock = await request(app.getHttpServer())
      .get('/matching/suggestions')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200);

    const afterUnblockSuggestions = toSuggestionsBody(afterUnblock.body);
    expect(
      afterUnblockSuggestions.some(
        (candidate) =>
          candidate.user.email === `safety-b-${unique}@e2e.sportsbuddy.dev`,
      ),
    ).toBe(true);

    expect(userAId.length).toBeGreaterThan(5);
  });

  it('creates reports and rate limits repeated reporting', async () => {
    const unique = Date.now().toString();
    const password = 'Password123!';

    const reporter = await registerUser(app, {
      name: 'Reporter',
      email: `reporter-${unique}@e2e.sportsbuddy.dev`,
      password,
    });
    const target = await registerUser(app, {
      name: 'Report Target',
      email: `target-${unique}@e2e.sportsbuddy.dev`,
      password,
    });

    const targetMe = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${target.accessToken}`)
      .expect(200);
    const targetId = readString(asRecord(targetMe.body), 'id');

    const firstResponse = await request(app.getHttpServer())
      .post('/safety/reports')
      .set('Authorization', `Bearer ${reporter.accessToken}`)
      .send({ userId: targetId, reason: 'spam' })
      .expect(201);
    const firstReport = toReportResponseBody(firstResponse.body);
    expect(firstReport.success).toBe(true);

    await request(app.getHttpServer())
      .post('/safety/reports')
      .set('Authorization', `Bearer ${reporter.accessToken}`)
      .send({ userId: targetId, reason: 'harassment' })
      .expect(201);

    await request(app.getHttpServer())
      .post('/safety/reports')
      .set('Authorization', `Bearer ${reporter.accessToken}`)
      .send({ userId: targetId, reason: 'fraud' })
      .expect(201);

    await request(app.getHttpServer())
      .post('/safety/reports')
      .set('Authorization', `Bearer ${reporter.accessToken}`)
      .send({ userId: targetId, reason: 'other' })
      .expect(429);
  });

  it('allows connected buddies to exchange chat messages', async () => {
    const unique = Date.now().toString();
    const password = 'Password123!';

    const userA = await registerUser(app, {
      name: 'Chat Sender',
      email: `chat-a-${unique}@e2e.sportsbuddy.dev`,
      password,
    });
    const userB = await registerUser(app, {
      name: 'Chat Receiver',
      email: `chat-b-${unique}@e2e.sportsbuddy.dev`,
      password,
    });
    const userC = await registerUser(app, {
      name: 'Not Buddy',
      email: `chat-c-${unique}@e2e.sportsbuddy.dev`,
      password,
    });

    const userBMe = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .expect(200);
    const userBId = readString(asRecord(userBMe.body), 'id');

    const userAMe = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200);
    const userAId = readString(asRecord(userAMe.body), 'id');

    const userCMe = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${userC.accessToken}`)
      .expect(200);
    const userCId = readString(asRecord(userCMe.body), 'id');

    const requestResponse = await request(app.getHttpServer())
      .post('/connections/requests')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({ receiverId: userBId })
      .expect(201);
    const connectionRequest = toConnectionRequestBody(requestResponse.body);

    await request(app.getHttpServer())
      .post(`/connections/requests/${connectionRequest.id}/respond`)
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .send({ action: 'accept' })
      .expect(201);

    const firstMessage = await request(app.getHttpServer())
      .post(`/chat/buddies/${userBId}/messages`)
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({ content: 'Let us play at 7 AM in City Court' })
      .expect(201);
    expect(readString(asRecord(firstMessage.body), 'content')).toContain(
      '7 AM',
    );

    await request(app.getHttpServer())
      .post(`/chat/buddies/${userBId}/messages`)
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({ content: 'Bring one extra racket if possible' })
      .expect(201);

    const conversation = await request(app.getHttpServer())
      .get(`/chat/buddies/${userAId}/messages?limit=10`)
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .expect(200);
    const messages = toRecordArray(conversation.body);
    expect(messages).toHaveLength(2);
    expect(readString(messages[0], 'content')).toContain('7 AM');
    expect(readString(messages[1], 'content')).toContain('extra racket');

    await request(app.getHttpServer())
      .post(`/chat/buddies/${userCId}/messages`)
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({ content: 'hello there' })
      .expect(400);
  });

  it('creates, discovers, joins, leaves, and updates session plans', async () => {
    const unique = Date.now().toString();
    const password = 'Password123!';

    const creator = await registerUser(app, {
      name: 'Plan Creator',
      email: `plan-a-${unique}@e2e.sportsbuddy.dev`,
      password,
    });
    const buddy = await registerUser(app, {
      name: 'Plan Buddy',
      email: `plan-b-${unique}@e2e.sportsbuddy.dev`,
      password,
    });
    const outsider = await registerUser(app, {
      name: 'Plan Outsider',
      email: `plan-c-${unique}@e2e.sportsbuddy.dev`,
      password,
    });

    const buddyMe = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${buddy.accessToken}`)
      .expect(200);
    const buddyId = readString(asRecord(buddyMe.body), 'id');

    const outsiderMe = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${outsider.accessToken}`)
      .expect(200);
    const outsiderId = readString(asRecord(outsiderMe.body), 'id');

    const connectResp = await request(app.getHttpServer())
      .post('/connections/requests')
      .set('Authorization', `Bearer ${creator.accessToken}`)
      .send({ receiverId: buddyId })
      .expect(201);
    const requestId = toConnectionRequestBody(connectResp.body).id;

    await request(app.getHttpServer())
      .post(`/connections/requests/${requestId}/respond`)
      .set('Authorization', `Bearer ${buddy.accessToken}`)
      .send({ action: 'accept' })
      .expect(201);

    const scheduledAt = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();

    const createdPlanResp = await request(app.getHttpServer())
      .post('/sessions/plans')
      .set('Authorization', `Bearer ${creator.accessToken}`)
      .send({
        scheduledAt,
        area: 'Koramangala 4th Block',
        sport: 'Pickleball',
        skillLevel: 'intermediate',
        maxPlayers: 4,
      })
      .expect(201);

    const createdPlan = asRecord(createdPlanResp.body);
    const planId = readString(createdPlan, 'id');
    expect(readString(createdPlan, 'status')).toBe('open');

    const discoverForBuddy = await request(app.getHttpServer())
      .get('/sessions/plans/discover')
      .set('Authorization', `Bearer ${buddy.accessToken}`)
      .expect(200);
    const discoverPlans = toRecordArray(discoverForBuddy.body);
    expect(discoverPlans).toHaveLength(1);
    expect(readString(discoverPlans[0], 'id')).toBe(planId);

    const discoverForOutsider = await request(app.getHttpServer())
      .get('/sessions/plans/discover')
      .set('Authorization', `Bearer ${outsider.accessToken}`)
      .expect(200);
    expect(toRecordArray(discoverForOutsider.body)).toHaveLength(0);

    await request(app.getHttpServer())
      .post(`/sessions/plans/${planId}/join`)
      .set('Authorization', `Bearer ${buddy.accessToken}`)
      .expect(201);

    await request(app.getHttpServer())
      .post(`/sessions/plans/${planId}/join`)
      .set('Authorization', `Bearer ${outsider.accessToken}`)
      .expect(400);

    const mineForBuddy = await request(app.getHttpServer())
      .get('/sessions/plans/mine')
      .set('Authorization', `Bearer ${buddy.accessToken}`)
      .expect(200);
    const buddyPlans = toRecordArray(mineForBuddy.body);
    expect(buddyPlans).toHaveLength(1);
    expect(readString(buddyPlans[0], 'id')).toBe(planId);

    await request(app.getHttpServer())
      .patch(`/sessions/plans/${planId}/status`)
      .set('Authorization', `Bearer ${creator.accessToken}`)
      .send({ status: 'confirmed' })
      .expect(200);

    await request(app.getHttpServer())
      .delete(`/sessions/plans/${planId}/join`)
      .set('Authorization', `Bearer ${buddy.accessToken}`)
      .expect(200)
      .expect({ success: true });

    await request(app.getHttpServer())
      .patch(`/sessions/plans/${planId}/status`)
      .set('Authorization', `Bearer ${outsider.accessToken}`)
      .send({ status: 'completed' })
      .expect(400);

    expect(outsiderId.length).toBeGreaterThan(5);
  });

  afterAll(async () => {
    await prisma.user.deleteMany({
      where: { email: { endsWith: '@e2e.sportsbuddy.dev' } },
    });
    await app.close();
  });
});
