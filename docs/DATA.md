# Data and sample

Source: [Yahoo Finance historical daily prices](https://finance.yahoo.com/). The archived input files, rather than a fresh API download, define this replication. Downloading today's adjusted history can change historical prices and will not necessarily reproduce the fixed snapshot.

The effective period ends on 31 December 2024. BTC and ETH each contribute 2,192 prices and 2,191 log returns; each ETF contributes 1,510 prices and 1,509 log returns. The raw cryptocurrency quote on 1 January 2025 is excluded. No 2025 extension is used.

The fixed universe is BTC-USD, ETH-USD, SPY, GLD, TLT, QQQ, IWM, EFA, EEM, XLF, XLE, XLU, SLV, LQD and VNQ. ETF returns use adjusted closes. Cryptocurrency prices use the available adjusted-close field, with close allowed if it is unavailable. Duplicate dates, nonpositive prices and missing values are rejected; prices are not imputed. Crypto horizons count calendar-day observations; ETF horizons count observed trading returns.

Evaluation uses 425 origins per cryptocurrency and 288 per ETF, common across H=10,20,30,40. Earlier evaluation outcomes may enter later fitting only after maturity. Chronological availability does not remove the separate specification-search issue arising from earlier development on the same sample.

`INPUT_MANIFEST.csv` records the fixed price-file hashes. The file names contain ticker identifiers solely for reproducibility; the figures use academic display labels.

Price data originate from a third party. The MIT software license does not grant rights over Yahoo Finance or its providers' data. Retain this attribution and consult the source's terms for reuse.
