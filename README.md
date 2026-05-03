# ECB Communication, CSPP, and Climate: Green vs Brown Bond Yields

Replication code for *[Paper title]*.

> This repository contains all Stata analysis code for the paper. The project studies how the ECB's Corporate Sector Purchase Programme (CSPP) and its climate-related communications affected the borrowing costs of green and brown firms, using bond-level yield-to-maturity data and firm-level equity returns around the announcement.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Data Sources](#2-data-sources)
3. [Data Pipeline](#3-data-pipeline)
4. [Repository Structure](#4-repository-structure)
5. [Setup](#5-setup)
6. [Key Variables](#6-key-variables)
7. [Notes on Data Access](#7-notes-on-data-access)

---

## 1. Project Overview

This project constructs and analyzes two complementary datasets:

- **Bond-level panel**: Weekly yield-to-maturity (YTM) for EUR-denominated corporate bonds, matched to firm-level emissions data, used to estimate the yield premium for green vs brown bonds around the ECB CSPP.
- **Firm-level event study**: Cumulative Abnormal Returns (CARs) around the ECB's climate-related CSPP announcement, comparing green and brown firms classified by Scope 1 and Scope 2 emissions.

The central questions are: (1) did CSPP eligibility compress green bond yields relative to comparable non-eligible bonds? (2) did the ECB's climate communication generate equity market losses for high-emission firms?

---

## 2. Data Sources

| Source | What it provides | Access |
|---|---|---|
| **Bloomberg** | Bond-level yield-to-maturity (YTM), coupon, amount issued, maturity, currency, ISIN | Licensed — requires terminal subscription |
| **ECB / CSPP** | List of CSPP-eligible bonds and purchase dates | Public — [ecb.europa.eu](https://www.ecb.europa.eu/mopo/implement/app/html/index.en.html) |
| **Compustat / WRDS** | Firm-level financials (size, leverage, sales), GVKEY identifiers | Licensed — requires WRDS subscription |
| **Refinitiv / Eikon** | ESG scores, Scope 1 and Scope 2 emissions, emissions intensity | Licensed |
| **STOXX 600** | Constituent list and sector classifications (GICS) | Licensed |
| **CRSP / Datastream** | Daily equity returns for event study | Licensed |
| **Climate Bonds Initiative** | Green bond issuance registry | Public — [climatebonds.net](https://www.climatebonds.net) |

---

## 3. Data Pipeline

```
RAW DATA SOURCES
─────────────────────────────────────────────────────────────────────
  Bloomberg         Compustat /        Refinitiv /      ECB / CSPP
  (Bond YTM,        WRDS               Eikon            (Eligible bond
   ISIN, coupon,    (Firm financials,  (Scope 1 & 2     list, purchase
   maturity)        GVKEY)             emissions, ESG)  dates)
      │                  │                  │                 │
      └──────────────────┴──────────────────┴─────────────────┘
                               │
                               ▼
            [Data construction — Python (not in this repo)]
                               │
               ┌───────────────┴───────────────┐
               ▼                               ▼
     bond_data.dta                    firm_level_data.csv
     YTM_all_Brown.dta                CARs.dta
     YTM_all_Green.dta
               │                               │
               ▼                               ▼
┌──────────────────────────────┐  ┌────────────────────────────────┐
│ DESCRIPTIVE STATISTICS       │  │ EVENT STUDY                    │
│ BondLvl_descstats.do         │  │ EventStudy.do                  │
│ FirmLvl_descstats.do         │  │                                │
│                              │  │ • t-tests on CARs by firm      │
│ • Bond count by type         │  │   greenness (Scope 1 & 2)      │
│ • YTM, maturity, coupon      │  │ • KS-tests on CAR distribution │
│ • Firm size, leverage, sales │  │ • MVE lost by brown firms      │
│ • Emissions by GICS sector   │  │ • Density plots by greenness   │
└──────────────────────────────┘  └────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────────┐
│ DIFFERENCE-IN-DIFFERENCES                                           │
│ DiD_Greenbonds.do  — green bond yield premium (CSPP effect)         │
│ DiD_Brownbonds.do  — brown firm yield penalty (emissions effect)    │
│                                                                     │
│ • Bond, week, issuer, country×month, sector×month FE               │
│ • Three control groups (non-credit EUR, credit EUR, SEK)            │
│ • Emissions measured by level and intensity, full and 4-digit GICS  │
│ • Standard errors clustered at ISIN level                           │
└─────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
                    output/tables/   output/figures/
                    (LaTeX tables)   (PNG density plots)
```

---

## 4. Repository Structure

```
cspp-climate/
│
├── README.md
├── .gitignore
│
├── stata/
│   ├── main.do                  ← master script: runs all steps in order
│   ├── mycodebook.do            ← helper: count distinct values per variable
│   │
│   ├── ── DESCRIPTIVE STATISTICS ──────────────────────────────────────
│   ├── BondLvl_descstats.do     ← summary stats at the bond level
│   ├── FirmLvl_descstats.do     ← summary stats + correlations at firm level
│   │
│   ├── ── DIFFERENCE-IN-DIFFERENCES ───────────────────────────────────
│   ├── DiD_Greenbonds.do        ← green bond yield premium around CSPP
│   ├── DiD_Brownbonds.do        ← brown firm yield penalty around CSPP
│   │
│   └── ── EVENT STUDY ─────────────────────────────────────────────────
│       └── EventStudy.do        ← CARs around ECB climate announcement
│
├── scheme/
│   └── scheme-uncluttered.scheme  ← custom Stata graph scheme
│
├── data/                        ← NOT committed to git (see .gitignore)
│   ├── raw/                     ← original vendor data exports
│   └── clean/                   ← analysis-ready .dta and .csv files
│       ├── bond_data.dta
│       ├── YTM_all_Brown.dta
│       ├── YTM_all_Green.dta
│       ├── CARs.dta
│       └── firm_level_data.csv
│
└── output/                      ← generated at runtime (git-ignored)
    ├── tables/                  ← LaTeX tables (.tex)
    └── figures/                 ← plots exported as .png
```

---

## 5. Setup

### Prerequisites

- Stata MP 16 or later
- The following user-written Stata packages (install once):

```stata
ssc install reghdfe
ssc install estout
ssc install distinct
ssc install tabout
```

- The `scheme-uncluttered.scheme` file must be on Stata's scheme search path. Copy it to your personal ado folder:

```bash
# macOS / Linux — find your ado path with: adopath
cp scheme/scheme-uncluttered.scheme ~/Library/Application\ Support/Stata/ado/personal/
```

### Configure paths

All do files read three globals for paths. The defaults point to the repo's own `data/` and `output/` folders. To override, set the globals before running:

```stata
global data    "/path/to/your/data/clean"
global tables  "/path/to/your/output/tables"
global figures "/path/to/your/output/figures"
do stata/main.do
```

### Run the full pipeline

```bash
stata-mp -b do stata/main.do
```

Or run individual steps directly from within Stata:

```stata
do stata/mycodebook.do       // always load this first
do stata/BondLvl_descstats.do
do stata/DiD_Brownbonds.do
```

---

## 6. Key Variables

**Bond-level panel** (`YTM_all_Brown.dta`, `YTM_all_Green.dta`):

| Variable | Description |
|---|---|
| `ISIN` | Bond identifier |
| `YTM` | Yield-to-maturity (%) |
| `ECB_ELIGIBLE` | 1 if bond is CSPP-eligible |
| `GREEN_BOND` | 1 if bond is a certified green bond |
| `POST` | 1 if date is after the ECB climate announcement |
| `WEEK` | Week fixed effect identifier |
| `MONTH` | Month fixed effect identifier |
| `COUNTRY` | Issuer country |
| `CURRENCY` | Bond currency |
| `GICS_4D` | 4-digit GICS sector code |
| `SCOPE_1_EMISSIONS_GREEN_F` | 1 if firm is in the bottom tercile of global Scope 1 emissions |
| `SCOPE_1_EMISSIONS_BROWN_F` | 1 if firm is in the top tercile of global Scope 1 emissions |
| `SCOPE_1_EMISSIONS_GREEN_4D` | 1 if firm is green relative to its 4-digit GICS sector |
| `SCOPE_1_EMISSIONS_BROWN_4D` | 1 if firm is brown relative to its 4-digit GICS sector |

**Firm-level event study** (`CARs.dta`):

| Variable | Description |
|---|---|
| `GVKEY` | Compustat firm identifier |
| `COMPANY_NAME` | Firm name |
| `CAR_before` | Cumulative abnormal return, pre-event window (−50, −11) days |
| `CAR_around` | Cumulative abnormal return, event window (−1, +1) days |
| `CAR_after` | Cumulative abnormal return, post-event window (+11, +36) days |
| `GREEN_BOND_ISSUER` | 1 if firm has ever issued a green bond |
| `IS_CSPP` | 1 if firm has or had a CSPP-eligible bond |
| `CREDIT` | 1 if firm is a credit institution |
| `MVE_5_business_days_before_event` | Market value of equity 5 days before the event |
| `SCOPE_1_EMISSIONS_GREEN_F` | Green firm indicator (global Scope 1 ranking) |
| `SCOPE_1_EMISSIONS_BROWN_F` | Brown firm indicator (global Scope 1 ranking) |
| `CSPPe_GB` | 1 if firm holds a CSPP-eligible green bond |

---

## 7. Notes on Data Access

Bond yield data from **Bloomberg**, firm financials from **Compustat/WRDS**, and emissions data from **Refinitiv/Eikon** are proprietary and cannot be redistributed. Researchers wishing to replicate this study will need independent access to these sources.

The ECB's list of CSPP-eligible securities and purchase holdings is publicly available at [ecb.europa.eu](https://www.ecb.europa.eu/mopo/implement/app/html/index.en.html).

Green bond issuance data from the **Climate Bonds Initiative** is publicly available at [climatebonds.net](https://www.climatebonds.net).

For questions about data construction, please open a GitHub Issue or contact the author.
