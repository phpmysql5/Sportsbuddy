# Sportsbuddy Monorepo

This workspace contains the initial Sports Buddy MVP foundation.

## Structure

- `backend/sports-buddy-api`: NestJS backend (generated and build-tested)
- `infra`: Docker Compose for Postgres (PostGIS) + Redis
- `mobile`: Flutter placeholder and next steps
- `docs`: Product brief and setup notes

## Current status

- Backend scaffold: complete
- Backend build check: passed
- Infra files: complete
- Docker runtime: missing on this machine
- Flutter runtime: missing on this machine

## Run backend

```powershell
cd c:\Users\karth\Sportsbuddy\backend\sports-buddy-api
npm.cmd run start:dev
```

## Bring up infra (after installing Docker Desktop)

```powershell
cd c:\Users\karth\Sportsbuddy\infra
docker compose up -d
```

## Create mobile app (after installing Flutter)

```powershell
cd c:\Users\karth\Sportsbuddy\mobile
flutter create sports_buddy_app
```

## MCP servers

The npm MCP server commands are reachable using `npx.cmd`.
You still need to register them in VS Code MCP manager so they appear as running servers.
