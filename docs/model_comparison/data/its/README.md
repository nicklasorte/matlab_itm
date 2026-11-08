# ITS Phase 2 irregular-terrain measurements

`its_phase2.zip` is the ITS "Phase 2" spot-measurement data set, downloaded on
2026-11-08 from the ITS legacy radio propagation data page,
https://its.ntia.gov/data/legacy-radio-propagation-data/ (`phase_2.zip`).
It is public NTIA data.

Five measurement sets, each with a parameter file (`..pars.txt`), a path file
(`..path.txt`), a data file (`..data.txt`), and, except R4, surveyed terrain
profiles (`.._pfl/*.pfl`, read from 1:24,000 and 1:62,500 topographic maps):

| Set | Environment | Dates | Frequencies (MHz) | Reference |
|---|---|---|---|---|
| R1 | Colorado plains, Gunbarrel Hill receiver | 1965-66 | 230, 410, 751, 910, 1846, 4595, 9190 | McQuate et al., ESSA Tech. Rep. ERL 65-ITS 58 (1968) |
| R2 | Colorado mountains, Fritz Peak receiver | 1966 | same | ERL 65-ITS 58-2 (1968) |
| R3 | North Table Mountain, Golden (air to ground) | 1966 | same | ERL 65-ITS 58-3 (1970) |
| R4 | Receiver in a grove of trees (no profiles) | 1966-67 | 230-9190 | OT/TRER 19 (1971) |
| VA | Virginia piedmont | 1967 | 76, 173, 409, 950, 2180, 4820, 8395 | Hufford and Steele, NTIA Report 91-282 (1991) |

Data values are attenuation relative to free space (dB) at the path
distance. 999 means no measurement. A value of 500 or more means the signal was
below the system's sensitivity, and the attenuation was greater than the value
minus 500 (a lower bound).

Colorado sets: transmitting antennas 6.6 m (230-751 MHz) or 7.3 m
(910-9190 MHz) above ground, horizontal polarization; the receiving antennas
were raised from 1 m to 13 m (15 m at R3), and `Rht` is that height in metres
(ERL 65-ITS 58, sections 2 and 3). Virginia: horizontal polarization,
transmitter and receiver heights per frequency in `vapars.txt`; `Rcvr` 1 or 2
picks the receiver van and its "Hi" height, and "Lo" is 2 m (NTIA Report
91-282, section 2).

Paths marked O (open) and C (concealed) share a path name: the concealed site
is behind trees or a building near the open one. A (alternate) is a third
site. `compare_its_phase2_rev1.m` reads the zip directly.
