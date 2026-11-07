# Data sources

| File | Source | Grid | SHA-256 |
| --- | --- | --- | --- |
| `TropoClim.txt` | ITU-R P.617-3 supplement, [R-REC-P.617-3-201309-S!!ZIP-E.zip](https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.617-3-201309-S!!ZIP-E.zip) | 360 × 720, 0.5°, rows from 89.75° N, columns from 179.75° W; codes 0 (sea) to 7 | `05fee4e835f8f54cc6cf32d093fa414addacc99fc94812bf209de1ee44ff717c` |
| `N050.TXT` | ITU-R P.452-16 supplement, [R-REC-P.452-16-201507-S!!ZIP-E.zip](https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.452-16-201507-S!!ZIP-E.zip) | 121 × 241, 1.5°, rows from 90° N, columns from 0° E | `d27590ce5c7cf7ff7b4457ce31b9bf3591f0b97e367732195de0f1a98bd35f2a` |

`itm_maps.mat` holds the same two grids as MATLAB variables `TropoClim`
and `N050`, converted from the text files with no change in value, so the
maps load in milliseconds instead of being parsed at startup.

Both text files are unmodified copies of the ITU-R digital products. `N050.TXT`
is byte-identical in the P.452-16 and P.452-18 supplements. These are the
files the WInnForum CBRS reference model retrieves
(`src/data/retrieve_itu_files.py`).

ITU-R Recommendations and their data are free to download from the ITU.
Check ITU's terms before redistributing them outside your organization.
