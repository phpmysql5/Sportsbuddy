# Four-User Real Data Results

Run time: 2026-07-12T15:54:02.578Z

## Users Created In This Run

- A: Aarav Vibe <aarav.vibe.1783871641286@maildrop.cc>
- B: Mia Pulse <mia.pulse.1783871641286@maildrop.cc>
- C: Zara Flux <zara.flux.1783871641286@maildrop.cc>
- D: Neel Drift <neel.drift.1783871641286@maildrop.cc>

| ID | Test | Result | Details |
|---|---|---|---|
| TC00 | API health | PASS | ok |
| TC01 | Metadata endpoints | PASS | cities=6, sports=6 |
| TC02 | Fresh registration x4 | PASS | A:aarav.vibe.1783871641286@maildrop.cc / B:mia.pulse.1783871641286@maildrop.cc / C:zara.flux.1783871641286@maildrop.cc / D:neel.drift.1783871641286@maildrop.cc |
| TC03 | Logout/login cycle x4 | PASS | all users relogged |
| TC04 | Profile update x4 | PASS | city/sports/skill/days saved |
| TC05 | A discover suggestions | PASS | count=10 |
| TC06 | A->C request accept | PASS | requestId=8124c88d-500f-4538-b167-f18450171e42 |
| TC07 | D->B request reject | PASS | requestId=527917cc-679e-467c-bd6a-7e9a65a298d0 |
| TC08 | A->D request cancel | PASS | requestId=20033e16-4d9c-4835-83eb-0012c44cefa1 |
| TC09 | A messages C | PASS | yo, 6 PM court vibe? |
| TC10 | Session lifecycle A/C | PASS | planId=b6304bff-230f-4b27-a1b3-f59ea2b14615 |
| TC11 | Safety block/report effect | PASS | reportId=3a826291-f00d-4860-8249-c779e3031345 |
| TC12 | Persistence relogin check | PASS | minePlans=1 |
