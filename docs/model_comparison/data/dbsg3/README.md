# ITU-R Study Group 3 databank, Table III

`itu_r_sg3_dbsg3_tableiii_data.zip` is the ITU-R SG3 databank (DBSG3) Table III
"long term" data download (ltpath, ltdata, and 397 surveyed path profiles),
from https://www.itu.int/oth/R0A04/en (free document). ITU-R material: keep this
repository private, as with the ITU maps.

`dbsg3_tableiii_30mhz_10ghz.csv` is built from it: every dataset from 30 MHz to
10 GHz with both site coordinates, both antenna heights, a measured median, and
loss relative to free space (608 datasets). Coordinates in Japan are converted
from the Tokyo datum to WGS84 with the GSI approximate formula; the listed
coordinates are kept alongside. `tx_ground_survey_m` and `rx_ground_survey_m`
are the first and last ground elevations of the surveyed profile (the first
point is the transmitter in every profile file).

Columns `a001` to `a9999` are the attenuation relative to free space (dB) not
exceeded for 0.01, 0.1, 1, 10, 50, 90, 99, 99.9, and 99.99 % of the time.

## VHF/UHF point-to-area data (Rec. ITU-R P.311 Tables VI-1 and VI-2)

- `itu_r_sg3_dbsg3_vhfuhf_rssdata.zip`: ITU-R SG3 databank of VHF/UHF measurements relating to terrestrial broadcasting, downloaded from https://www.itu.int/oth/R0A0400005B/en (free). Spatial records (Table VI-2) in bands 1 to 7 (30 MHz to 3 GHz) in `disk1` and `disk2`; surveyed profiles in `disk3` to `disk5`.
- `dbsg3_area_30mhz_3ghz.csv`: every spatial record parsed by `compare_dbsg3_area_rev1.m`. Column 40 of the .SPL files is the field strength exceeded at 50 % of locations for 1 kW e.r.p.; `meas_50` is basic transmission loss, 141.45 - E + 20 log10(f_MHz).
