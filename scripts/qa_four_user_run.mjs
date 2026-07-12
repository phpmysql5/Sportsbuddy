import fs from 'node:fs/promises';
import path from 'node:path';

const base = 'http://localhost:3000';
const results = [];

function addResult(id, name, passed, details) {
  results.push({ id, name, passed, details });
}

async function req(method, p, body, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${base}${p}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = {};
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      throw new Error(`Non-JSON response (${res.status}): ${text}`);
    }
  }
  if (!res.ok) {
    const msg = Array.isArray(data?.message) ? data.message.join(', ') : data?.message || `HTTP ${res.status}`;
    throw new Error(msg);
  }
  return data;
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

async function main() {
  try {
    const health = await req('GET', '/health');
    assert(health.status === 'ok', 'Health endpoint not ok');
    addResult('TC00', 'API health', true, 'Health returned ok');

    const users = {
      A: { email: 'arjun.mangalore@sportsbuddy.dev', password: 'Demo@1234', city: 'Mangalore', sports: ['Tennis', 'Football'], skill: 'beginner', days: ['Tue', 'Thu'] },
      B: { email: 'neha.mangalore@sportsbuddy.dev', password: 'Demo@1234', city: 'Mangalore', sports: ['Tennis', 'Badminton'], skill: 'intermediate', days: ['Tue', 'Thu'] },
      C: { email: 'rohan.mangalore@sportsbuddy.dev', password: 'Demo@1234', city: 'Mangalore', sports: ['Cricket', 'Tennis'], skill: 'beginner', days: ['Tue', 'Fri'] },
      D: { email: 'ava@sportsbuddy.dev', password: 'Demo@1234', city: 'Bengaluru', sports: ['Basketball', 'Football'], skill: 'advanced', days: ['Sat', 'Sun'] },
    };

    const sessions = {};

    for (const key of Object.keys(users)) {
      const u = users[key];
      const auth = await req('POST', '/auth/login', { email: u.email, password: u.password });
      assert(auth.accessToken, `Missing access token for ${key}`);
      sessions[key] = { access: auth.accessToken, user: auth.user };
    }
    addResult('TC01', 'Login four users', true, 'All four users logged in');

    for (const key of Object.keys(users)) {
      const u = users[key];
      const s = sessions[key];
      const profile = await req('PUT', '/profile', {
        city: u.city,
        sport: u.sports[0],
        sports: u.sports,
        skillLevel: u.skill,
        availabilityDays: u.days,
      }, s.access);
      assert(profile.city === u.city, `Profile city mismatch for ${key}`);
    }
    addResult('TC02', 'Profile update four users', true, 'All profiles updated');

    const suggestionsA = await req('GET', '/matching/suggestions', null, sessions.A.access);
    assert(Array.isArray(suggestionsA), 'Suggestions response invalid');
    addResult('TC03', 'Discover suggestions for A', suggestionsA.length >= 1, `A suggestion count: ${suggestionsA.length}`);

    const cId = sessions.C.user.id;
    const acReq = await req('POST', '/connections/requests', { receiverId: cId }, sessions.A.access);
    assert(acReq.status === 'pending', 'A->C request not pending');
    addResult('TC04', 'A sends request to C', true, `requestId=${acReq.id}`);

    const acAccept = await req('POST', `/connections/requests/${acReq.id}/respond`, { action: 'accept' }, sessions.C.access);
    assert(acAccept.status === 'accepted', 'A->C request not accepted');
    addResult('TC05', 'C accepts A request', true, 'Request accepted');

    const buddiesA = await req('GET', '/connections/buddies', null, sessions.A.access);
    assert(buddiesA.some((b) => b.id === cId), 'C missing in A buddies');
    const msg = await req('POST', `/chat/buddies/${cId}/messages`, { content: 'yo lets play at 6pm' }, sessions.A.access);
    assert(typeof msg.content === 'string', 'Message send failed');
    addResult('TC06', 'A buddy chat with C', true, 'Buddy exists and message sent');

    const scheduledAt = new Date(Date.now() + 3 * 3600 * 1000).toISOString();
    const plan = await req('POST', '/sessions/plans', {
      scheduledAt,
      area: 'Mangalore',
      sport: 'Tennis',
      skillLevel: 'beginner',
      maxPlayers: 4,
    }, sessions.A.access);
    assert(plan.id, 'Missing plan id');

    const discoverC = await req('GET', '/sessions/plans/discover', null, sessions.C.access);
    assert(discoverC.some((p) => p.id === plan.id), 'C cannot discover A plan');

    const joined = await req('POST', `/sessions/plans/${plan.id}/join`, {}, sessions.C.access);
    assert(joined.joined === true, 'C join failed');

    const left = await req('DELETE', `/sessions/plans/${plan.id}/join`, null, sessions.C.access);
    assert(left.success === true, 'C leave failed');
    addResult('TC07', 'Session create/discover/join/leave', true, `planId=${plan.id}`);

    const dId = sessions.D.user.id;
    const block = await req('POST', '/safety/blocks', { userId: dId }, sessions.A.access);
    assert(block.success === true, 'Block failed');

    const suggestionsA2 = await req('GET', '/matching/suggestions', null, sessions.A.access);
    assert(!suggestionsA2.some((s) => s?.user?.id === dId), 'Blocked user D still visible in A suggestions');
    addResult('TC08', 'Block affects discover visibility', true, 'Blocked user removed from suggestions');
  } catch (e) {
    addResult('FAIL', 'Run aborted', false, e?.message || String(e));
  }

  const lines = [];
  lines.push('# Four-User Active Usage Run Results');
  lines.push('');
  lines.push(`Run time: ${new Date().toISOString()}`);
  lines.push('');
  lines.push('| ID | Test | Result | Details |');
  lines.push('|---|---|---|---|');
  for (const r of results) {
    lines.push(`| ${r.id} | ${r.name} | ${r.passed ? 'PASS' : 'FAIL'} | ${String(r.details).replaceAll('|', '/')} |`);
  }

  const reportPath = path.resolve(process.cwd(), 'docs', 'QA_4_USER_RESULTS.md');
  await fs.writeFile(reportPath, `${lines.join('\n')}\n`, 'utf8');
  console.log(`Report written: ${reportPath}`);
}

await main();
