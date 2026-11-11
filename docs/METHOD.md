# Method and output mapping

The target at the close of origin t is the sum of the next h squared close-to-close log returns. A label from s is eligible when s+h ≤ t. All four maximum horizons use common evaluation origins within each asset.

Monthly ridge fits use current squared return and its five- and 22-observation means. Complete 40-step labels must mature by the fit date. Penalty selection uses a purged chronological inner tail and the first 30 coordinates. Rolling estimation restricts training origins to the preceding 1,096 calendar days. Predictions are projected separately after truncation to H. EWMA decay is fixed at 0.94.

MCPB uses up to 252 eligible origins separately at each horizon and a common coefficient pair across its path. The positive quadratic penalty is centered at (0,1), with lambda equal to kappa times half the trace of the expert Gram matrix. The main kappa is 10^-4; 10^-6 and 10^-2 are sensitivities.

| Numerical identifier | Publication label | Calibration rule |
| --- | --- | --- |
| Ridge | Ridge | Raw multiresponse ridge |
| Ridge_PAV | Isotonic ridge | Nonnegative monotone projection |
| EWMA | EWMA | Cumulative fixed-decay forecast |
| RidgeEWMA | Ridge–EWMA | Monthly simplex; complete 40-step labels |
| DailyMix40 | Daily 40 | Daily simplex; complete 40-step labels |
| DailyMixH | Daily H | Daily simplex; complete H-step labels |
| MaturityMix | Maturity simplex | Daily simplex; coordinate-specific eligibility |
| CalEWMA | Calibrated EWMA | Ridge coefficient zero; MCPB penalty value retained |
| NNLS_FullH | Full-path positive | Daily positive coefficients; complete H-step labels |
| MCPB | MCPB | Daily positive coefficients; coordinate-specific eligibility |

The primary inferential family is the 30 H=30 expanding-window MSE comparisons with EWMA and Ridge–EWMA at block length 30. The separate component family contains 60 comparisons with Daily 40, maturity simplex, calibrated EWMA and full-path positive regression. Daily H is descriptive and outside that component family. Other horizons, windows, block lengths and QLIKE are secondary analyses.

Positive PRE means lower candidate MSE. QLIKE is reported as a loss difference, not a percentage ratio. Zero and shape-violation thresholds use an absolute 10^-12 in original squared-log-return units. The distinct historical TV experiment uses its own stated scale-relative fusion convention.

The original Turkish development declaration is preserved byte for byte in `evidence/DECLARED_MCPB_STUDY.md` because its checksum is part of provenance. This English documentation does not relabel that declaration as preregistration. All user-facing execution instructions are in English.
