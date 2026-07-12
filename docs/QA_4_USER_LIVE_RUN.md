# Live 4-User App Test Log (Gen Z Real Usage)

This log is for active app testing with four users using current features only.

## Users (Create Fresh In App)
1. A: ____________________
2. B: ____________________
3. C: ____________________
4. D: ____________________
Passwords:
- A: __________
- B: __________
- C: __________
- D: __________

Suggested diversity:
- A/B same city, overlapping sports
- C same city with partial overlap
- D different city and different sports

## Execution Style
- Simulate active usage (quick switches, retries, concurrent expectations).
- Keep natural behavior: search, connect, message, plan, block/report.
- No Google login in this run.

## Data Integrity Rule
- No seeded/demo/pre-filled account evidence in this run.
- Every row must come from actions done by these four freshly created users.

## Manual Active Usage Sequence

### S1 Profile and Discovery Readiness
| Step | Actor | Action | Expected | Actual | Result |
|---|---|---|---|---|---|
| S1.1 | A | Register via email/password | Registration success and signed in |  |  |
| S1.2 | B | Register via email/password | Registration success and signed in |  |  |
| S1.3 | C | Register via email/password | Registration success and signed in |  |  |
| S1.4 | D | Register via email/password | Registration success and signed in |  |  |
| S1.5 | A/B/C/D | Logout then login again | Home screen opens |  |  |
| S1.6 | A/B/C/D | Save valid profile with city+sports+days | Profile updated |  |  |
| S1.7 | Any | Try invalid city/manual text | Save blocked/rejected |  |  |
| S1.8 | Any | Try zero selected sports | Save blocked |  |  |

### S2 Search and Match Relevance
| Step | Actor | Action | Expected | Actual | Result |
|---|---|---|---|---|---|
| S2.1 | A | Discover list refresh | Suggestions load |  |  |
| S2.2 | A | Search by city "mangalore" | Mangalore users filtered |  |  |
| S2.3 | A | Search by sport "tennis" | Tennis overlap users shown |  |  |
| S2.4 | A | Global Search filters city+game | Suggestions/buddies/plans respect filters |  |  |

### S3 Connections Lifecycle
| Step | Actor | Action | Expected | Actual | Result |
|---|---|---|---|---|---|
| S3.1 | A | Send request to C | A=Requested, C=incoming |  |  |
| S3.2 | C | Accept A request | Both become buddies |  |  |
| S3.3 | D | Send request to B | B incoming request appears |  |  |
| S3.4 | B | Reject D request | No buddy formed |  |  |
| S3.5 | A | Send request to D then cancel | Request removed both sides |  |  |

### S4 Messaging and Session Plan
| Step | Actor | Action | Expected | Actual | Result |
|---|---|---|---|---|---|
| S4.1 | A | Message C after connection | Message sent and visible in recent thread |  |  |
| S4.2 | A | Plan a game from C | Area from city list, sport from supported list |  |  |
| S4.3 | A | Create session plan | Plan created |  |  |
| S4.4 | C | Discover and join A's plan | Join success, participant count updates |  |  |
| S4.5 | C | Leave plan | Participant count decreases |  |  |
| S4.6 | A | Update plan status open->confirmed->completed | Status transitions persist |  |  |

### S5 Safety and Persistence
| Step | Actor | Action | Expected | Actual | Result |
|---|---|---|---|---|---|
| S5.1 | A | Block D | D removed from A discover where applicable |  |  |
| S5.2 | A | Report D | Report submitted success |  |  |
| S5.3 | A/B/C/D | Logout then login | Data persists (profile/connections/plans) |  |  |

## UX Polish Notes (Current Features Only)
Score each 1-5 during run:
- Action feedback speed:
- Clarity of status and errors:
- Search usefulness:
- Connection flow smoothness:
- Session flow smoothness:
- Safety action confidence:

Top 5 improvements to current features only:
1.
2.
3.
4.
5.
