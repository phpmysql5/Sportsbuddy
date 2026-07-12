# Sports Buddy API Contract (Current)

Base URL:
- local Android emulator: http://10.0.2.2:3000
- local desktop/web: http://localhost:3000

Auth model:
- Access token: short-lived JWT, sent as Bearer token.
- Refresh token: rotated token returned by auth endpoints.

## Health

GET /health
- auth: none
- response 200
```json
{ "status": "ok" }
```

## Auth

POST /auth/register
- auth: none
- throttle: 5 requests/minute
- body
```json
{ "name": "User", "email": "user@example.com", "password": "password123" }
```
- response 201
```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "user": {
    "id": "...",
    "email": "user@example.com",
    "name": "User",
    "city": null,
    "sport": null,
    "skillLevel": null,
    "availabilityDays": []
  }
}
```

POST /auth/login
- auth: none
- throttle: 8 requests/minute
- body
```json
{ "email": "user@example.com", "password": "password123" }
```
- response: same shape as register

POST /auth/google
- auth: none
- throttle: 8 requests/minute
- body
```json
{ "idToken": "google-id-token" }
```
- response: same shape as register/login

POST /auth/refresh
- auth: none
- throttle: 20 requests/minute
- body
```json
{ "refreshToken": "..." }
```
- response 201
```json
{ "accessToken": "...", "refreshToken": "..." }
```

GET /auth/me
- auth: Bearer access token
- response 200 PublicUser

POST /auth/logout
- auth: Bearer access token
- response 201
```json
{ "success": true }
```

## Profile

GET /profile
- auth: Bearer access token
- response 200 PublicUser

PUT /profile
- auth: Bearer access token
- body
```json
{
  "city": "Mangalore",
  "sport": "Tennis",
  "skillLevel": "beginner",
  "availabilityDays": ["Sat", "Sun"]
}
```
- response 200 PublicUser

Validation notes:
- city and sport min length = 2
- skillLevel in [beginner, intermediate, advanced]
- availabilityDays max 7 unique strings

## Matching

GET /matching/suggestions
- auth: Bearer access token
- response 200
```json
[
  {
    "user": { "id": "...", "email": "...", "name": "...", "city": "...", "sport": "...", "skillLevel": "...", "availabilityDays": [] },
    "score": 3,
    "reasons": ["Same city", "Same sport", "Shared availability"]
  }
]
```

Matching notes:
- city and sport compare case-insensitively after trimming whitespace.
- skill gap must be <= 1 level.
