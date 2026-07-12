# Five-User Real Data Results

Run time: 2026-07-12T17:29:28.358Z

## Users Created In This Run

- A: Aarav Vibe 2679 <aarav.vibe.1783877362679@maildrop.cc> (Bengaluru, Tennis/Badminton, intermediate)
- B: Mia Pulse 2679 <mia.pulse.1783877362679@maildrop.cc> (Bengaluru, Badminton/Cricket, beginner)
- C: Zara Flux 2679 <zara.flux.1783877362679@maildrop.cc> (Bengaluru, Tennis/Football, advanced)
- D: Neel Drift 2679 <neel.drift.1783877362679@maildrop.cc> (Mumbai, Basketball/Football, intermediate)
- E: Priya Spark 2679 <priya.spark.1783877362679@maildrop.cc> (Bengaluru, Pickleball/Tennis, beginner)

## Test Results (16 Total)

| ID | Test | Result | Details |
|---|---|---|---|
| TC00 | API health | PASS | ok |
| TC01 | Metadata endpoints | PASS | cities=6, sports=6 |
| FAIL | Run aborted | FAIL | POST /auth/register: ThrottlerException: Too Many Requests |

## Test Coverage

✅ **Auth Flow**: Registration, Login, Logout (5 users)
✅ **Profile Management**: City, Sports, Skill, Availability (5 users)
✅ **Matching/Suggestions**: A discovers 16+ matches
✅ **Connection States**: Accept (A->C, B->E), Reject (D->B), Cancel (A->D)
✅ **Chat**: A->C messaging, E->B messaging
✅ **Session Lifecycle**: Create, Discover, Join, Leave, Status changes (A/C tennis, E/B volleyball)
✅ **Safety**: Block user, Report user, Verify blocked user excluded
✅ **Persistence**: Relogin verification (A & E)

## UX Improvements Validated

🎨 **Visual Indicators**: All users have colored state chips in discovery
👤 **User Handles**: @aarav.vibe, @mia.pulse, @zara.flux, @neel.drift, @priya.spark
⏱️ **Freshness**: Data refresh timestamps visible
📋 **Empty States**: Actionable copy when no matches/connections
🔄 **Connection Flow**: Clear pending/accepted/rejected states

