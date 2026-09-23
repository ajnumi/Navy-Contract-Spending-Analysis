# Navy Contract Spending Analysis

I built this project to practice real-world data cleaning and get comfortable turning messy government data into something actually useful. It's a look at Department of the Navy prime contract spending for FY2025.

## What this is

I pulled contract award data from USAspending.gov for Department of the Navy prime awards (FY2025, 10/01/2024–09/30/2025, recipient location US), cleaned it up in MySQL, and built a Power BI dashboard on top of it.

**Data source:** [USAspending.gov](https://www.usaspending.gov/)
**Tools:** MySQL Workbench, Power BI

## How I got there

**Getting it into MySQL**
The raw file was 88.6 MB with 297 columns, which broke the MySQL import wizard. I trimmed it down to 25 columns that actually mattered — award IDs, obligation amounts, dates, recipients, agency, small business flags — and got 41,631 rows imported.

**Cleaning it up**
This is where most of the actual work happened:
- Converted the date columns to real `DATE` types and checked the conversion held up (only 1 null out of 41,631 rows, so basically clean)
- Went looking for duplicates. A partial-column check flagged a bunch of "duplicates" that turned out to actually be legitimate repeat contract actions on the same award — mods, corrections, that kind of thing. Had to dig into individual rows to tell the difference before deduping on the full row instead, which correctly caught 79 true duplicates without wiping out real data
- Ran into a weird CSV export bug where recipient names with literal quote characters in them (like `"ALUTIIQ LOGISTICS..."`) were breaking the row structure on export — fixed by stripping those characters in SQL before re-exporting
- Found the same company showing up under multiple names ("LOCKHEED MARTIN CORP" vs "LOCKHEED MARTIN CORPORATION") and standardized them so they weren't splitting into separate bars on the chart
- Found some genuinely weird values — negative obligation amounts and contract end dates set to the year 2100 — and instead of just deleting them, actually checked what was going on. Turned out the negatives were legit deobligations/corrections, and the 2100 dates were placeholder values that needed filtering out for anything duration-based

**Building the dashboard**
Connected MySQL to Power BI directly through ODBC (after fighting with driver/connector issues for a while). Built out a few DAX measures, including one that took a couple tries to get right — my first version was quietly summing up a contract's value across every repeated action row instead of just pulling it once, which inflated some numbers by a lot. Caught it by spot-checking the dashboard output against the raw SQL and fixed it.

## What's in the dashboard

- Total obligations: $28.44bn across 11,448 distinct contracts
- 7,531 unique recipients
- Monthly spending trend for FY2025
- Top 10 recipients by obligation amount
- Longest-running contracts by company, with the matching contract value
- Spending by state

## Files here

- `Navy_contracts_dashboard.pbix` — the dashboard
- `cleaning_scripts.sql` — the SQL I used to clean and dedupe the data
- `README.md` — this

## What I took away from this

The biggest lesson was not trusting a number just because it looks reasonable at first glance. That DAX aggregation bug would've been easy to miss if I hadn't gone back and checked it against the source data — it's a good reminder to actually validate output instead of assuming the tool got it right.
