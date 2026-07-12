# Four-User Real-App QA Execution (No Google Login)

## Objective
Run a realistic four-user journey on current app features only:
- Email register/login
- Profile setup
- Discover and search
- Connection request lifecycle (send/accept/reject/cancel)
- Messaging
- Session planning (create/discover/join/leave/status)
- Safety actions (report/block)

No new features are introduced in this test. This validates what exists today.

## Preconditions
1. Backend API reachable at `http://localhost:3000`.
2. Mobile app points to emulator host `10.0.2.2:3000` on Android.
3. Start from clean/new user data for this run (no demo account dependency).
4. Use one device sequentially (logout/login) or two devices in parallel.

## Four Users
Create four fresh users from the app register screen at runtime:
1. User A: ____________________ / __________
2. User B: ____________________ / __________
3. User C: ____________________ / __________
4. User D: ____________________ / __________

Suggested profile diversity after registration:
- A and B: same city, overlapping sports
- C: same city as A/B but different overlap pattern
- D: different city and different sports

## Test Flow

### Phase 1: Login and Profile Validation
1. Register each user with email/password from app UI.
- Expected: Registration success and authenticated session created.
2. Login each user with email/password.
- Expected: Login success and Home screen loaded.
3. Open profile editor for each user and confirm city and sports are from supported lists.
- Expected: City chip options and sports chips match backend-supported values.
4. Try saving profile with invalid state:
- empty sports
- invalid city (manual text)
- Expected: Save blocked with clear status message.
5. Save valid profile updates.
- Expected: Status shows `Profile updated` and values persist after relogin.

### Phase 2: Discover and Search
1. For each user, open Discover.
- Expected: If profile incomplete, discover gate appears; otherwise suggestions load.
2. Run discover search queries by:
- name
- city
- sport
- Expected: Correct filtering for all query types.
3. Open Search tab and use filters:
- location filter
- game filter
- Expected: Suggestions, buddies, and plans reflect selected filters.

### Phase 3: Connections Lifecycle
1. A sends request to C.
- Expected: A shows `Requested`; C sees incoming request.
2. C accepts A.
- Expected: Both appear under Connected Buddies.
3. D sends request to B; B rejects.
- Expected: No buddy relationship created.
4. A sends request to D then cancels.
- Expected: Request removed from A outgoing and D incoming.

### Phase 4: Messaging
1. From A to C (connected pair), send message.
- Expected: `Message sent` and recent thread displays message.
2. Verify C can view recent messages with A.
- Expected: Thread contents visible and ordered.

### Phase 5: Session Plan Lifecycle
1. A opens `Plan a Game` from C.
- Expected: Area uses city dropdown only, sport uses supported sports list.
2. Create plan with valid values.
- Expected: `Session plan created` and plan appears in A `Session Plans`.
3. Login C and verify plan appears in discoverable session list (if eligible).
- Expected: C can join plan.
4. C joins and later leaves.
- Expected: Participant count updates correctly.
5. A updates status through `open -> confirmed -> completed`.
- Expected: Status updates visible and persistent.

### Phase 6: Safety and Reliability
1. Report a user from Discover/Connections safety menu.
- Expected: `Report submitted`.
2. Block a user and refresh Discover/Connections.
- Expected: Blocked user no longer appears where applicable.
3. Logout/login all four users.
- Expected: Profiles, connections, and plans persist.

## Pass/Fail Sheet
Record each test as you execute.

| ID | Test Case | User(s) | Expected | Actual | Result (Pass/Fail) | Evidence |
|---|---|---|---|---|---|---|
| TC01 | Email login works | A/B/C/D | Home loads |  |  |  |
| TC02 | Profile invalid save blocked | A | Clear validation message |  |  |  |
| TC03 | Valid profile save | A/B/C/D | Profile updated persists |  |  |  |
| TC04 | Discover gate if incomplete | Any | Gate shown |  |  |  |
| TC05 | Discover search by name/city/sport | A/B | Correct filtering |  |  |  |
| TC06 | A->C request send/accept | A/C | Connected both sides |  |  |  |
| TC07 | D->B request reject | D/B | No connection |  |  |  |
| TC08 | A->D request cancel | A/D | Request removed |  |  |  |
| TC09 | A->C messaging | A/C | Message in recent thread |  |  |  |
| TC10 | A creates session plan | A | Plan created |  |  |  |
| TC11 | C joins/leaves A plan | A/C | Count/status correct |  |  |  |
| TC12 | Safety report/block | Any pair | Action reflected in UI |  |  |  |
| TC13 | Logout/login persistence | A/B/C/D | Data persists |  |  |  |

## Improvement Review (2026 Gen Z/Public polish, no new features)
After execution, score each category from 1 (poor) to 5 (excellent):
1. Speed feedback: how fast actions feel in UI.
2. Clarity of status and error text.
3. Friction in profile, request, and plan flows.
4. Consistency of button/chip states across tabs.
5. Search/filter usefulness in real use.

Then capture top 5 improvements on existing screens only:
1. 
2. 
3. 
4. 
5. 

## Suggested gate before release
1. Backend: `npm run build`, `npm run test -- --runInBand`, `npm run test:e2e`
2. Mobile: `flutter analyze`, `flutter test`
3. Manual: all critical cases TC01-TC11 pass
