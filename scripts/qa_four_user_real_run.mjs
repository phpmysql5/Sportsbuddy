import fs from 'node:fs/promises';
import path from 'node:path';

const base = 'http://localhost:3000';
const now = Date.now();

const suffix = String(now).slice(-4);

const users = [
  {
    key: 'A',
    name: `Aarav Vibe ${suffix}`,
    email: `aarav.vibe.${now}@maildrop.cc`,
    password: 'VibePass@2026',
    city: 'Bengaluru',
    sports: ['Tennis', 'Badminton'],
    skill: 'intermediate',
    days: ['Tue', 'Thu'],
  },
  {
    key: 'B',
    email: `mia.pulse.${now}@maildrop.cc`,
    name: `Mia Pulse ${suffix}`,
    password: 'PulsePass@2026',
    city: 'Bengaluru',
    sports: ['Badminton', 'Cricket'],
    skill: 'beginner',
    days: ['Tue', 'Thu'],
  },
  {
    key: 'C',
    email: `zara.flux.${now}@maildrop.cc`,
    name: `Zara Flux ${suffix}`,
    password: 'FluxPass@2026',
    city: 'Bengaluru',
    sports: ['Tennis', 'Football'],
    skill: 'advanced',
    days: ['Tue', 'Fri'],
  },
  {
    key: 'D',
    email: `neel.drift.${now}@maildrop.cc`,
    name: `Neel Drift ${suffix}`,
    password: 'DriftPass@2026',
    city: 'Mumbai',
    sports: ['Basketball', 'Football'],
    skill: 'intermediate',
    days: ['Sat', 'Sun'],
  },
];

const results = [];
const sessions = new Map();

const add = (id, name, passed, details) => {
  results.push({ id, name, passed, details });
};

async function req(method, p, body, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(`${base}${p}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await res.text();
  const data = text ? JSON.parse(text) : {};

  if (!res.ok) {
    const msg = Array.isArray(data?.message)
      ? data.message.join(', ')
      : data?.message || `HTTP ${res.status}`;
    throw new Error(`${method} ${p}: ${msg}`);
  }

  return data;
}

function must(cond, msg) {
  if (!cond) throw new Error(msg);
}

async function main() {
  try {
    const health = await req('GET', '/health');
    must(health.status === 'ok', 'Health not ok');
    add('TC00', 'API health', true, 'ok');

    try {
      const cities = await req('GET', '/meta/supported-cities');
      const sports = await req('GET', '/meta/supported-sports');
      add('TC01', 'Metadata endpoints', true, `cities=${cities.cities.length}, sports=${sports.sports.length}`);
    } catch (err) {
      add('TC01', 'Metadata endpoints', false, `Optional check failed: ${err?.message || String(err)}`);
    }

    // register fresh users
    for (const u of users) {
      const auth = await req('POST', '/auth/register', {
        name: u.name,
        email: u.email,
        password: u.password,
      });
      must(auth.accessToken, `missing token for ${u.key}`);
      sessions.set(u.key, { access: auth.accessToken, refresh: auth.refreshToken, user: auth.user, cfg: u });
    }
    add('TC02', 'Fresh registration x4', true, users.map((u) => `${u.key}:${u.email}`).join(' | '));

    // logout + login for realism
    for (const u of users) {
      const s = sessions.get(u.key);
      await req('POST', '/auth/logout', {}, s.access);
      const auth = await req('POST', '/auth/login', { email: u.email, password: u.password });
      sessions.set(u.key, { access: auth.accessToken, refresh: auth.refreshToken, user: auth.user, cfg: u });
    }
    add('TC03', 'Logout/login cycle x4', true, 'all users relogged');

    // profile save
    for (const u of users) {
      const s = sessions.get(u.key);
      const profile = await req('PUT', '/profile', {
        city: u.city,
        sport: u.sports[0],
        sports: u.sports,
        skillLevel: u.skill,
        availabilityDays: u.days,
      }, s.access);
      must(profile.city === u.city, `profile city mismatch ${u.key}`);
    }
    add('TC04', 'Profile update x4', true, 'city/sports/skill/days saved');

    // suggestions for A
    const a = sessions.get('A');
    const aSuggestions = await req('GET', '/matching/suggestions', null, a.access);
    add('TC05', 'A discover suggestions', Array.isArray(aSuggestions) && aSuggestions.length > 0, `count=${aSuggestions.length}`);

    // A sends to C, C accepts
    const c = sessions.get('C');
    const reqAC = await req('POST', '/connections/requests', { receiverId: c.user.id }, a.access);
    must(reqAC.status === 'pending', 'A->C pending failed');
    const accepted = await req('POST', `/connections/requests/${reqAC.id}/respond`, { action: 'accept' }, c.access);
    must(accepted.status === 'accepted', 'A->C accept failed');
    add('TC06', 'A->C request accept', true, `requestId=${reqAC.id}`);

    // D sends to B, B rejects
    const d = sessions.get('D');
    const b = sessions.get('B');
    const reqDB = await req('POST', '/connections/requests', { receiverId: b.user.id }, d.access);
    const rejected = await req('POST', `/connections/requests/${reqDB.id}/respond`, { action: 'reject' }, b.access);
    must(rejected.status === 'rejected', 'D->B reject failed');
    add('TC07', 'D->B request reject', true, `requestId=${reqDB.id}`);

    // A sends to D then cancels
    const reqAD = await req('POST', '/connections/requests', { receiverId: d.user.id }, a.access);
    await req('DELETE', `/connections/requests/${reqAD.id}`, null, a.access);
    add('TC08', 'A->D request cancel', true, `requestId=${reqAD.id}`);

    // A chats C
    const msg = await req('POST', `/chat/buddies/${c.user.id}/messages`, { content: 'yo, 6 PM court vibe?' }, a.access);
    must(typeof msg.content === 'string', 'chat send failed');
    add('TC09', 'A messages C', true, msg.content);

    // session plan lifecycle
    const plan = await req('POST', '/sessions/plans', {
      scheduledAt: new Date(Date.now() + 2 * 3600 * 1000).toISOString(),
      area: 'Bengaluru',
      sport: 'Tennis',
      skillLevel: 'intermediate',
      maxPlayers: 4,
    }, a.access);
    must(plan.id, 'plan create failed');

    const discoverC = await req('GET', '/sessions/plans/discover', null, c.access);
    must(discoverC.some((p) => p.id === plan.id), 'plan not discoverable for C');
    const joined = await req('POST', `/sessions/plans/${plan.id}/join`, {}, c.access);
    must(joined.joined === true, 'join failed');
    const left = await req('DELETE', `/sessions/plans/${plan.id}/join`, null, c.access);
    must(left.success === true, 'leave failed');
    await req('PATCH', `/sessions/plans/${plan.id}/status`, { status: 'confirmed' }, a.access);
    await req('PATCH', `/sessions/plans/${plan.id}/status`, { status: 'completed' }, a.access);
    add('TC10', 'Session lifecycle A/C', true, `planId=${plan.id}`);

    // safety block + report A blocks D and reports D
    const block = await req('POST', '/safety/blocks', { userId: d.user.id }, a.access);
    must(block.success === true, 'block failed');
    const report = await req('POST', '/safety/reports', { userId: d.user.id, reason: 'spam', details: 'test run' }, a.access);
    must(report.success === true, 'report failed');

    const postBlockSuggestionsA = await req('GET', '/matching/suggestions', null, a.access);
    const containsD = postBlockSuggestionsA.some((s) => s?.user?.id === d.user.id);
    must(!containsD, 'blocked D still visible in A suggestions');
    add('TC11', 'Safety block/report effect', true, `reportId=${report.reportId}`);

    // persistence quick check via relogin A
    await req('POST', '/auth/logout', {}, a.access);
    const aRelogin = await req('POST', '/auth/login', { email: a.cfg.email, password: a.cfg.password });
    const aMine = await req('GET', '/sessions/plans/mine', null, aRelogin.accessToken);
    must(Array.isArray(aMine), 'persistence check failed');
    add('TC12', 'Persistence relogin check', true, `minePlans=${aMine.length}`);
  } catch (err) {
    add('FAIL', 'Run aborted', false, err?.message || String(err));
  }

  const lines = [];
  lines.push('# Four-User Real Data Results');
  lines.push('');
  lines.push(`Run time: ${new Date().toISOString()}`);
  lines.push('');
  lines.push('## Users Created In This Run');
  lines.push('');
  for (const u of users) {
    lines.push(`- ${u.key}: ${u.name} <${u.email}>`);
  }
  lines.push('');
  lines.push('| ID | Test | Result | Details |');
  lines.push('|---|---|---|---|');
  for (const r of results) {
    lines.push(`| ${r.id} | ${r.name} | ${r.passed ? 'PASS' : 'FAIL'} | ${String(r.details).replaceAll('|', '/')} |`);
  }

  const reportPath = path.resolve(process.cwd(), 'docs', 'QA_4_USER_RESULTS_REAL.md');
  await fs.writeFile(reportPath, `${lines.join('\n')}\n`, 'utf8');
  console.log(reportPath);
}

await main();
