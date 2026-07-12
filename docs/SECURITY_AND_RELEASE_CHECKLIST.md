# Security and Release Checklist

## Branch and PR controls

- Protect main branch in GitHub repository settings.
- Require at least 1 pull request review.
- Require CI checks to pass before merge.
- Disable force pushes on protected branch.

## Environment and secrets

- Set strong JWT secrets (access + refresh) per environment.
- Keep GOOGLE_CLIENT_ID aligned with mobile build configuration.
- Never commit .env files or credentials.
- Rotate secrets if leaked or shared accidentally.

## CORS and transport

- Restrict CORS origins to known frontend hosts in staging/production.
- Serve API over HTTPS only in non-local environments.

## Auth abuse controls

- Route-level throttling enabled for register/login/google/refresh.
- Monitor repeated 401/429 responses and block abusive IPs if needed.

## Safety abuse controls

- Keep report endpoint throttle active (3/minute per client key).
- Verify block and report actions reject self-targeting requests.
- Confirm blocked users are excluded from suggestions and connection interactions.
- Review report volume trends during pilot for spam patterns.

## Database migration flow

- Local development:
  1. npm run prisma:migrate:dev
  2. npm run prisma:generate
- CI:
  1. npm run prisma:generate
  2. npm run prisma:db:push (test DB only)
- Staging/Production:
  1. npm run prisma:migrate:deploy
  2. npm run prisma:generate

Do not use prisma db push against production databases.

## Observability

- Ensure structured request logs are enabled (request id, path, status, duration).
- Keep API health endpoint monitored.
- Alert on high 5xx rates and auth endpoint spikes.

## Pre-release smoke tests

- Register/login/logout/refresh flow works.
- Profile update validates and saves correctly.
- Suggestions return expected matches.
- Block user removes them from suggestions and connection lists.
- Report user returns success and enforces 429 on burst reporting.
- Connected buddies can exchange chat messages.
- Non-buddies are blocked from chat endpoints.
- Google sign-in end to end works with live client IDs.
- Session plan create/discover/join/leave/status-update flow works.
- Non-buddies cannot join session plans.
- Session status updates are allowed only for the plan creator.
