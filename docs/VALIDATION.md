# Validation completed on 11 November 2026

A fresh full run used R 4.3.3 with no cached expert bank. It repeated current-study ridge selection, monthly expert fitting, daily calibration and 4,999 bootstrap draws for each specified block setting across all 120 designs.

| Check | Observed result |
| --- | --- |
| R functional checks | 14/14 pass |
| Parent numerical parity checks | 2,400/2,400 pass |
| Fresh-versus-archived summary checks | 63/63 pass |
| Fitted array audit | 120 cases; 11,025,600 forecasts pass |
| Independent positive-regression comparisons | 360/360 pass |
| Publication export regression checks | 22/22 pass |

The summary comparison covers 1,440 accuracy rows, 6,480 inference rows, 36,752 coefficient rows and 870 monthly fit records. Maximum path-MSE discrepancy is approximately 9.90×10^-19; PRE discrepancies are at numerical rounding scale. Bootstrap p values and both Holm-adjusted p-value columns agree exactly. The unchanged core MD5 is `7198511bb116a1cd872cc25dc94122cc`.

The array audit recomputes targets from prices and checks projection, coefficient combinations, origin-level MSE/QLIKE, early-horizon scores and numerical shape diagnostics. The recorded-solution audit checks all 36,752 main coefficient pairs and compares 360 with SciPy nonnegative least squares; its maximum coefficient difference is approximately 1.54×10^-13.

These checks establish agreement with the stated frozen computation. They do not make the 120 overlapping cases independent replications, provide new unexamined data, or establish superiority over close controls. Models are not refitted inside bootstrap draws. Additional parent benchmarks and the historical TV estimators were not rerun; their archived aggregate records retain their distinct limitations.

Historical bibliography metadata files retain their original audit date. They are documentation, not a new external validation of the empirical method. `FRESH_R_SESSION_INFO.txt` identifies the environment of the completed R rerun; `SOFTWARE_VERSIONS.json` describes the Python publication environment.
