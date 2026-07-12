# Sports Buddy

Sports Buddy is a Flutter + NestJS prototype for finding nearby sports partners based on city, sport, skill level, and shared availability.

## Repository structure

- `backend/sports-buddy-api`: NestJS API with Prisma, JWT auth, Google sign-in, profile, and matching
- `mobile/sports_buddy_app`: Flutter app for auth, profile editing, and suggestions
- `infra`: local dependencies (Postgres/PostGIS and Redis via Docker Compose)
- `docs`: project notes and brief

## Quick start

### 1) Start infrastructure

```powershell
cd infra
docker compose up -d
```

### 2) Start backend

```powershell
cd backend/sports-buddy-api
npm.cmd install
npm.cmd run prisma:generate
npm.cmd run start:dev
```

### 3) Seed demo users

```powershell
cd backend/sports-buddy-api
npm.cmd run seed:demo
```

### 4) Run mobile app

```powershell
cd mobile/sports_buddy_app
flutter pub get
flutter run
```

## Demo accounts

All demo users share the same password:

- `Demo@1234`

Seeded emails:

- `ava.tennis@sportsbuddy.dev`
- `ryan.tennis@sportsbuddy.dev`
- `maya.badminton@sportsbuddy.dev`
- `noah.cricket@sportsbuddy.dev`
- `sara.tennis@sportsbuddy.dev`
- `arjun.mangalore@sportsbuddy.dev`
- `neha.mangalore@sportsbuddy.dev`
- `rohan.mangalore@sportsbuddy.dev`

## Fast demo flow

1. Login with any seeded account.
2. Open profile and save `city`, `sport`, `skill`, and `availability days`.
3. Refresh suggestions to view ranked buddies.
4. Logout, switch account, and compare matches.

Tip: for immediate visible matches, use city `Mangalore`, sport `Tennis`, and include `Sat` in availability.

## Quality checks

Backend:

```powershell
cd backend/sports-buddy-api
npm.cmd run lint
npm.cmd run build
npm.cmd test -- --runInBand
npm.cmd run test:e2e -- --runInBand
```

Mobile:

```powershell
cd mobile/sports_buddy_app
flutter analyze
flutter test
```
