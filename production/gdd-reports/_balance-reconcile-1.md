# Balance reconcile 1 (2026-11-03)

## Decision: one reference DPS, owned by Plane kits
`ref_dps = 800` = floor100(min(Lancer 857.8, Leech 832.5)) at **2 drones** (middle of 0-4; K8 cycle assumptions, eta included, on target).
Per drone count (Lancer / Leech): 0: 586.8 / 570.0; 1: 722.3 / 701.2; 2: 857.8 / 832.5; 3: 993.3 / 963.7; 4: 1,128.8 / 1,094.9.
0-drone player takes ~1.4x the TTK/fight targets; 4-drone ~0.73x.

## Changes (file: old -> new, why)
### plane-kits-lancer-leech.md
- K8 Output Range: added "Reference DPS for content budgets" note + per-drone table; 46,000 hp labelled as 4-drone ceiling (2-drone ref ~33,600 per 60 s).
- Design constraints "Hp reference": 1,100 / 580 -> ref_dps 800.
- Open Question 1: closed (Scoring re-baselined).
### design/registry/entities.yaml
- enemy_ref_dps 300: `status: deprecated` + comment, referenced_by emptied (not deleted).
- Added ref_dps 800, ref_uptime_pct 70, peak_value 1,300.
- Co-op hp / enemy spawn hp outputs: 450 -> 1,125 became 1,200 -> 3,000; MEDIUM 1,200-1,500, LARGE 4,000-5,000.
### enemy-and-ai.md (hp x 8/3, TTK targets 1.5 s / 5 s kept; SMALL 20/40/50 unchanged)
- hp_base: Flak gunner 450 -> 1,200; Radar gunner 560 -> 1,500; Heavy bomber 1,500 -> 4,000; Missile carrier 1,880 -> 5,000.
- ref_dps 300 -> 800 (range 150-600 -> 400-1,200); hp_base range 20-2,000 -> 20-6,000.
- F4 examples: bomber N2/N4 2,250/3,750 -> 6,000/10,000; carrier N3 3,760 -> 10,000; gunner N3/N4 900/1,125 -> 2,400/3,000.
- F8: plating dealt 300 -> 800; bomber ttk 360 (same), carrier ttk 436 -> 435, required 611 -> 609, gunner ttk 90 (same); ttk range 8-436 -> 3-435.
- AC-19, AC-22, AC-41, defaults line, tuning rows, decision note, Open Question 1 updated.
### boss-and-boss-parts.md (hp x 8/3 rounded to 100; denominator 21,000 -> 56,000)
- Fortress: turrets 900 -> 2,400; engines 1,200 -> 3,200; core 6,200 -> 16,500 (critical 930 -> 2,475, main 5,270 -> 14,025). T_fight 2,706 -> 2,703 (45.05 s); enrage_start 4,700 (same).
- Jet Carrier: pods 700 -> 1,900; wings 1,550 -> 4,100; core 7,400 -> 19,700 (main 16,745). T_fight 3,284 -> 3,285 (54.75 s); enrage 5,700 (same).
- Plasma Ring: shields 1,100 -> 2,900; core 7,800 -> 20,800 (main 17,680). T_fight 3,153 -> 3,138 (52.3 s); enrage 5,500 (same).
- F3 Fortress N=1..4 core: 16,500 / 24,750 / 33,000 / 41,250; critical 2,475 / 3,713 / 4,950 / 6,188; main 14,025 / 21,037 / 28,050 / 35,062; turret N4 2,250 -> 6,000. hp_base range 1-12,000 -> 1-30,000.
- F7 example total 10,400 -> 27,700, bar 596 -> 595. ref_dps 300 -> 800 (range 400-1,200). Rule 22 free-time hp 1,200 -> ~3,100 (same 5.6 s). AC-02, AC-12, AC-17, AC-19, AC-32 (lint test uses ref_dps 400), defaults, F10 table, Open Question 7 updated.
- Checked: critical window ratio unchanged (7 s x 20 % armour chips ~45 % of critical hp at ref dps, as before); core stays >= 1 hp so the window still cannot end the fight by chip damage. 7 s window still fine. Enrage ticks/stall bound (F11) unchanged because fight lengths unchanged.
### scoring.md F7 re-baseline
- Hits waves/boss: competent 12,000 / 5,150 -> 6,300 / 2,700 (45 hits/s); expert 20,000 / 7,500 -> 9,600 / 3,600 (60 hits/s, = Leech tap+latch landed max). Novice unchanged (inside capability).
- Medals/gems (coordinator input from powerups-and-drops): medals 25/40/40 -> 3/4/4 per stage; gems unchanged. S7: 35,000 / 120,000 / 770,000 -> 13,000 / 48,000 / 374,000.
- `peak_value` 1,000 -> 1,300 (range 500-2,000) to keep competent ~3M. `extend_unit` 3,000,000 untouched. `cb_unit` unchanged.
- S1: novice 172,500 (same); competent 1,597,750 -> 872,250; expert 24,700,000 -> 11,856,000.
- S8: 245,000 / 1,100,000 / 1,449,000 -> 254,000 / 1,295,000 / 1,748,700. F5 max 1,599,000 -> 1,898,700.
- Totals: novice 607,500 -> 594,500; competent 3,589,750 -> **2,987,250**; expert 32,653,000 -> **19,712,700**.
- Chain share (strict): novice 27 % -> 29 %; competent 71.8 % -> **71.2 %** (2,127,250 / 2,987,250); expert 94.6 % -> **93.8 %** (18,484,700 / 19,712,700). Both pass (>= 65 / >= 90).
- Extends: competent first extend (2.4M) now on the BOSS_PEAK line of the stage 1 tally, second on stage 2 tally (was during boss / mid-stage 2). Expert: both in stage 1 waves.
- Updated: F5 range/example, F7 tables and text, tuning row, ACs 23, 24, 45-48, defaults line, Open Question 1.
### coop-and-team-chain.md
- F8: competent S1_boss 637,750 -> 368,250, total 3,589,750 -> 2,987,250: bonus 2.4 / 3.6 / 4.7 % (was 3.4 / 5.1 / 6.6); expert S1_boss 7.5M -> 3.6M, total 19,712,700: 3.5 / 5.2 / 6.8 %.
- 4P chain share competent 67.0 % -> 67.9 % (2,127,250 / 3,134,550); expert 86.6 / 94.6 % -> 87.4 / 94.2 %. AC-35 updated.
- F6: added check against kits: pool share 150/slot vs kits <= 48 live, refused_player_share 0; eta (0.65-1.0) kept; 4P fights ~43-53 s.

## Unresolved / for others
- powerups-and-drops.md (not edited) still cites "32.65M expert" and "3.59M competent" in F9 (gem share 1.0 % / 1.7 %); recompute vs 19.71M / 2.99M (about 1.7 % / 2.0 %).
- bombs.md / boss-power-budget.md (not edited): any hp or dps assumption of 300, 1,100 or old S1 totals must use ref_dps 800 and the new hp.
- Bullet pattern library density / Boss 7 s critical window: no change needed; pattern density is bullet-based and fight lengths are unchanged (45-55 s).
- Thin spots: competent 4P chain share is 67.9 % (margin ~3 pt); expert 93.8 % (margin ~4 pt). Fight lengths for 0-drone players ~1.4x.
- Scoring F8 hard bound "under 100M" text was left (true bound is now ~31M at 72 hits/s; conservative).
- Other docs untouched (e.g. systems-index, production reports/session-state).
