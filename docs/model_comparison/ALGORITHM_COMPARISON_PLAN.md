# Plan: ITM and P.2001, equation by equation

This plan extends the working paper's section "How ITM and P.2001 compute
each mechanism" (revision 4) into a comparison that pairs every equation in
the two loss calculations. It is also printed in the paper, so the two copies
should be kept the same. Status values: **done** (in revision 4), **next**
(planned for revision 5), **later**.

Conventions:

- ITM references are line ranges in `private/itm_p2p_core.m` at commit
  `5081c68` of nicklasorte/matlab_itm (the port of NTIA ITM v1.4).
- P.2001 references are sections and equations of Recommendation ITU-R
  P.2001-6 (09/2025) and files in nicklasorte/itu_p2001 at commit `286e68c`.
- Every item has one test case, one CSV written by MATLAB, and one figure
  drawn by Python. The test cases reuse the paper's profiles (smooth earth in
  central Kansas, the 60 eastern and 60 western links, the five archetypes)
  unless the item says otherwise.
- The order is by expected effect on a 3 GHz separation distance, largest
  first.

## 1. The equation ledger

One row per step of the calculation. "Same inputs" asks whether the two
models start the step from the same quantities; where they don't, the
difference in inputs is usually a bigger cause than the difference in
formulas.

| # | Step | ITM v1.4 | P.2001-6 | Same inputs? | Test case | Figure | Status |
|---|------|----------|----------|--------------|-----------|--------|--------|
| 1 | Profile preparation | Equally spaced profile; horizons found by maximum elevation angle on the effective earth (L245-275) | Equally spaced profile; horizons by the same rule on a_e at p% (sec. 3.7) | Yes | 120 links, 30 m and 10 m spacing | Horizon distance and angle, ITM against P.2001, one point per link and terminal | done (resolution study); next (horizon scatter) |
| 2 | Terrain irregularity | Δh: interdecile range about a straight-line fit, scaled by (1 − 0.8 e^(−d/50 km)) (L277-330) | No Δh; roughness h_m for ducting is the highest terrain above the smooth surface between horizons (sec. 3.8) | No | 120 links | Δh against h_m, colored by the ITM minus P.2001 gap | next |
| 3 | Effective antenna heights | Height above a least-squares fit to the terrain near each antenna, over 15 h_g to 0.1 d_L (L210-243) | Height above a smooth surface fitted to the whole profile, two variants: h_tep, h_rep for diffraction, h_tea, h_rea for ducting (sec. 3.8) | No | 120 links | Dumbbell per link: ITM h_e and P.2001 h_tep for each terminal | next |
| 4 | Earth curvature | γ_e = γ_a(1 − 0.04665 e^(N_s/179.3)); N_s from N_0 and mean elevation; fixed over time (L191-208) | a_e50 = 157 a/(157 + ΔN); ΔN from a map; a_e(p) from map slopes (sec. 3.4.1, 3.5) | No (N_0 versus ΔN map) | Smooth earth, 120 km, 10 U.S. midpoints | Effective earth radius against time percentage, both models, 10 locations | done (one location); next (10 locations) |
| 5 | Region selection and combination | Line of sight if d < d_sML; diffraction up to d_x; scatter beyond (L393-484) | Four sub-models always computed; power sum by correlation (sec. 5, eqs. 5.1 and 5.2, Attachment J) | No | Smooth earth sweep; 120 links | Architecture diagram; mechanism agreement matrix | done |
| 6 | Free space | 32.45 + 20 log f + 20 log d (L667-669) | Same, with the slant distance including the height difference (sec. 3.11) | Yes | Any | None needed; difference under 0.01 dB on the paper's paths | done (noted) |
| 7 | Knife-edge function | 6.02 + 9.11√v² − 1.27v² (v² < 5.76), else 12.953 + 10 log v² (L512-518) | J(ν) = 6.9 + 20 log(√((ν − 0.1)² + 1) + ν − 0.1) for ν > −0.78 (sec. 3.12, eq. 43) | Yes | ν from 0 to 10 | Both against the Fresnel integral | done |
| 8 | Which edges | One edge at each horizon, v from the horizon angles and distances (L503-510) | One equivalent Bullington edge where the lines from the terminals to their steepest obstacles cross (A.4, eqs. A.15 to A.22) | No | 20 km single knife edge; two-obstacle family (see item 20) | Loss against obstacle height for one and two obstacles | done (one edge); next (two obstacles) |
| 9 | Smooth-earth diffraction | Vogler three-radius method: G(x) − F(x_1) − F(x_2) − 20 with K from the ground constants (L520-560) | First-term spherical-earth loss −F_X − G(Y_t) − G(Y_r) with K from the ground constants (A.2, A.3, eqs. A.8 to A.14) | Yes, if the same a_e and heights are given | Smooth earth 20 km to 300 km, 30 m and 10 m antennas, both polarizations | Both smooth-earth losses against distance, with their difference | next |
| 10 | Blending the diffraction terms | A_d = w A_se + (1 − w) A_k + A_fo; w from Δh, f, and the horizon geometry; A_fo ≤ 15 dB (L486-501) | L_d = L_dba + max(L_dsph − L_dbs, 0): the smooth-earth excess over a smooth Bullington path is added to the actual Bullington loss (A.1, eq. A.1) | No | 120 links | Term stack per model on the diffraction links (ITM: w A_se, (1 − w) A_k, A_fo; P.2001: J(ν), the empirical term, the spherical excess) | done (ITM terms); next (P.2001 terms beside them) |
| 11 | Empirical additions | A_fo = min(15, 5 log(1 + 10⁻⁵ h_g1 h_g2 f σ_h)) (L491) | (1 − e^(−J/6))(10 + 0.02 d) (A.4, eq. A.23) | No | 120 links | Both terms against path length | next |
| 12 | Where diffraction is evaluated | At d_3 = max(d_sML, d_L + 5X) and d_4 = d_3 + 10X, X = (a_e²/f)^(1/3); straight line to the path (L393-398) | At the path's distance | No | Smooth 120 km; rough western link; 120 links | ITM construction lines (done); ITM evaluated at the path instead of extended, against P.2001 (ablation, done) | done |
| 13 | Line of sight | Two-ray with complex reflection coefficient and roughness, weighted with the diffraction line by 1/(1 + f Δh/max(10 km, d_sML)); evaluated at d_0, d_1, d_sML and fitted (L412-453, L562-581) | Free space, gases, Bullington loss if the Fresnel zone is obstructed, and the clear-air fading term (sec. 4.1, A.4 case 1, Attachment B) | No | Smooth earth 1 km to 40 km; the 24 line-of-sight links | Both against a two-ray reference (done); fade depth against time percentage at 1 km to 40 km (next) | done; next |
| 14 | Troposcatter | A_s = F(θd) + 10 log(k H θ⁴) − 0.1(N_s − 301) e^(−θd/40 km) + H_0, at d_L + 200 km and d_L + 400 km (L583-657) | L_bs = M + L_freq + L_dist + L_coup − Y_p, climate zone from a map at the common volume, floored at free space (Attachment E, eqs. E.16, E.17) | No | Smooth earth 70 km to 700 km; 10 climate zones | Both against distance (done); troposcatter loss by climate zone, ITM climates 1 to 7 against P.2001 zones 1 to 6 (next) | done; next |
| 15 | Diffraction to scatter transition | Crossover d_x where the scatter line meets the diffraction line; scatter line joined there (L456-482) | None: the power sum lets the lower loss dominate smoothly | No | Smooth earth; 120 links | dL/dd against distance, both models, to show ITM's slope change at d_x and d_sML | next |
| 16 | Ducting and layer reflection | None | L_ba = A_ac + A_ad + A_at: coupling (site shielding, sea), angular distance, and time term from β (Attachment D, eqs. D.1 to D.25) | Not applicable | Smooth earth at 1%; over-sea archetype; 120 links at 0.1%, 1%, 10% | P.2001's three ducting terms against distance; ITM minus P.2001 against β | done (ducting section); next (term split) |
| 17 | Time variability | Effective distance d_e; climate curves for time, location, and situation; A_ref + V(p) (L674-795) | Each mechanism's own statistics: a_e(p) for diffraction, β and A_at(p) for ducting, Y_p for troposcatter, Q_caf and Q_rain for fading (sec. 4, Attachments B, C, D, E) | No | Five archetypes; smooth 120 km; rough link | Loss against time percentage with P.2001 sub-models (done); the same against measured distributions from the databank (next) | done; next |
| 18 | Gases, rain, sporadic-E | None explicit | Attachments F, C, G | Not applicable | Smooth earth at 3 GHz and 10 GHz | Size of each term against frequency, to show where they start to matter | later |
| 19 | Polarization and ground | ε_r, σ enter Z_g for the two-ray and smooth-earth terms (L191-208) | ε_r, σ enter K in the spherical-earth term only (A.3) | Partly | Smooth earth, both polarizations, three grounds | Loss difference between polarizations, both models | later |

## 2. Experiments that isolate one equation at a time

These go beyond reading the code: each swaps or holds one quantity so the
effect of a single difference can be measured.

| # | Experiment | What it isolates | Test case | Output | Status |
|---|-----------|------------------|-----------|--------|--------|
| 20 | Two-obstacle family | Item 8: one Bullington edge against two horizon edges | Synthetic profiles with two knife edges of heights h_1, h_2 at 1/3 and 2/3 of a 30 km path, h from 0 to 300 m | Heat map of ITM minus P.2001 over (h_1, h_2) | next |
| 21 | Roughness family | Items 2 and 10: how the gap grows with Δh | Random rough profiles (filtered noise) scaled to Δh from 10 m to 1,000 m, 10 km to 150 km, 20 draws each | Heat map of the median gap over (Δh, d); the paper's "divergence window" drawn from synthetic terrain | next |
| 22 | Earth-radius swap | Item 4 | Smooth earth and 120 links with ITM run at P.2001's a_e50 (through N_0) and P.2001 run at ITM's a_e | Gap before and after the swap | next |
| 23 | Effective-height swap | Item 3 | 120 links with each model given the other's effective heights (code change in a test branch, not in the released functions) | Gap before and after | later |
| 24 | Evaluation-point swap | Item 12 | ITM evaluated at the path (done in the ablation) and P.2001 evaluated at d_3 and d_4 and extended | Gap before and after | next |
| 25 | Monte Carlo combination | Item 5: the single-percentage blend of sec. 5.2 against the Monte Carlo method of sec. 5.3 | Five archetypes, 10,000 draws | Loss against time percentage, both combinations, with their difference | next |
| 26 | Reciprocity | Both models should give the same loss with the terminals swapped; P.2001 states it (sec. 1.2) | 120 links, both directions | Largest asymmetry per model | next |
| 27 | Continuity | Items 13 and 15 | Smooth earth and 120 radial paths at 100 m steps | Jumps in loss and slope at d_sML, d_x, and the Bullington LoS or NLoS switch | next |
| 28 | Input sensitivity per equation | Which inputs each equation is most sensitive to | 120 links, one input at a time (N_0 or ΔN, ε_r, σ, spacing, antenna heights ±1 m) | Tornado chart per model | done (sensitivity section, in part); next (per equation) |
| 29 | Measured distributions | Item 17 | Databank Table III paths with several time percentages | ITM and P.2001 against the measured distribution per path | next |

## 3. Figure plan

Each figure states one idea, uses gray for context and one accent for the
point, and labels marks directly. ITM is light blue, P.2001 dark blue, and
the difference purple, as elsewhere in the paper. All data come from the
MATLAB CSV files; Python draws only.

| Figure | Type | Axes and marks | The one callout |
|--------|------|----------------|-----------------|
| Equation map | Two-column flow diagram (done as the architecture figure); next version adds the equation numbers and code lines in each box | Boxes per step, arrows for data flow | Where the two columns stop matching |
| Horizon scatter (item 1) | Scatter with the equal line | ITM horizon distance against P.2001's, one point per terminal | Points off the line are the links where the horizons differ |
| Roughness measures (item 2) | Scatter | Δh against h_m, log axes, colored by gap | The gap follows Δh, not h_m |
| Effective heights (item 3) | Dumbbell | One row per link; ITM h_e and P.2001 h_tep as two dots joined by a line | Links where ITM's effective height is tens of metres above P.2001's |
| Earth radius (item 4) | Small multiples, 10 locations | Radius against time percentage, log x | ITM flat; P.2001 rising to the left |
| Smooth-earth diffraction (item 9) | Two lines and a difference band | Loss against distance | The two methods agree within a stated tolerance |
| Term stacks (item 10) | Paired stacked bars, one pair per link class | Median dB per term | The ITM term that has no counterpart |
| Empirical additions (item 11) | Two lines | dB against path length | Where each add-on reaches its cap |
| Two-obstacle heat map (item 20) | Heat map with a zero contour | h_1 by h_2, color is ITM minus P.2001, diverging palette with gray at zero | The band where one edge and two edges agree |
| Roughness heat map (item 21) | Heat map with contours at 10 dB and 20 dB | Δh by d, log axes | The synthetic terrain reproduces the measured divergence window |
| Swap experiments (items 22 to 24) | Slope chart | Gap before and after each swap, one line per experiment | The swap that closes most of the gap |
| Monte Carlo combination (item 25) | Line with a band | Loss against time percentage; blend and Monte Carlo | Largest difference in dB and at which percentage |
| Continuity (item 27) | Small multiples of dL/dd | Slope against distance for both models | ITM's steps at d_sML and d_x |
| Tornado (item 28) | Two tornado charts side by side | Change in loss per input | The input that moves each model most |
| Measured distributions (item 29) | Small multiples of CDFs | Loss against time percentage per path: measured, ITM, P.2001 | Which model follows the measured tail |

## 4. Order of work

1. Items 20, 21, and 24 (the diffraction geometry): they explain most of the
   gap on rough terrain and need only synthetic profiles.
2. Items 9, 10, 11 (the diffraction terms side by side) and 16 (the ducting
   terms): one MATLAB export each from code already in both repos.
3. Items 2, 3, 22, 26, 27 (inputs, swaps, reciprocity, continuity): cheap
   checks that catch implementation differences.
4. Items 14, 17, 25, 29 (troposcatter, variability, Monte Carlo, measured
   distributions): the time-distribution work.
5. Items 18, 19, 23 (later).

## 5. Checks

- Every number quoted in the paper's text comes from `numbers_3ghz.json`,
  which `paper_numbers_3ghz_rev1` writes; no number is typed by hand.
- Before a new figure is used, its MATLAB run reproduces one published or
  reference value: the ITM test suite (NTIA examples) and the ITU-R P.2001
  validation set (4,430 cases) both pass at the cited commits.
- Each experiment runs on both models through the same profile struct, so a
  difference can't come from terrain preparation.
- An independent review of the finished section by someone who hasn't seen
  the drafts is still required before the paper circulates.
