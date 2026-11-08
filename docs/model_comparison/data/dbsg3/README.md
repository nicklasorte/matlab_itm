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
