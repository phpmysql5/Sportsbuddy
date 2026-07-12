# Four-User Real Data Results

Run time: 2026-07-12T17:22:30.814Z

## Users Created In This Run

- A: Aarav Vibe 9647 <aarav.vibe.1783876949647@maildrop.cc>
- B: Mia Pulse 9647 <mia.pulse.1783876949647@maildrop.cc>
- C: Zara Flux 9647 <zara.flux.1783876949647@maildrop.cc>
- D: Neel Drift 9647 <neel.drift.1783876949647@maildrop.cc>

| ID | Test | Result | Details |
|---|---|---|---|
| TC00 | API health | PASS | ok |
| TC01 | Metadata endpoints | PASS | cities=6, sports=6 |
| TC02 | Fresh registration x4 | PASS | A:aarav.vibe.1783876949647@maildrop.cc / B:mia.pulse.1783876949647@maildrop.cc / C:zara.flux.1783876949647@maildrop.cc / D:neel.drift.1783876949647@maildrop.cc |
| TC03 | Logout/login cycle x4 | PASS | all users relogged |
| TC04 | Profile update x4 | PASS | city/sports/skill/days saved |
| TC05 | A discover suggestions | PASS | count=16 |
| TC06 | A->C request accept | PASS | requestId=806154e6-bdff-4f39-acc0-cfcea38007ab |
| TC07 | D->B request reject | PASS | requestId=c16d6bcc-b7d7-493a-90de-aa856965bfba |
| TC08 | A->D request cancel | PASS | requestId=3df3b21a-c20f-473f-9791-9027871f0dfc |
| TC09 | A messages C | PASS | yo, 6 PM court vibe? |
| TC10 | Session lifecycle A/C | PASS | planId=7fa8ca31-df00-4fe5-8113-0a90be0055ee |
| TC11 | Safety block/report effect | PASS | reportId=94a664bb-0848-4b7e-bb08-2dff536d452c |
| TC12 | Persistence relogin check | PASS | minePlans=1 |
