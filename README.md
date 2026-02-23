# Credit Card Fraud Risk Analysis

## Project Background
Credit card fraud costs businesses and consumers billions of dollars annually. This project analyzes 1.3 million real credit card transactions to identify where, when, and how fraud occurs — and which customers are most at risk. The goal was to build an analysis that a risk team could actually use to make decisions.

---

## Data Source
- **Dataset:** Credit Card Fraud Dataset (2019–2020)
- **Source:** Kaggle
- **Size:** 1.3 million transactions
- **Fields include:** Transaction date, amount, merchant category, customer location, and fraud flag (0 = legitimate, 1 = fraud)

---

## Data Cleaning Process
Before any analysis was run the data was validated and cleaned in SQL Server.

**Issues found and fixed:**

**1. Duplicate table conflict**
The CSV import created a table with an auto-generated name. Renamed to `fraud_clean` for cleaner querying.

**2. Extra whitespace in text columns**
Several columns contained leading and trailing spaces which would cause WHERE clause filters to fail silently. Fixed using TRIM across all affected columns:
```sql
UPDATE fraud_clean
SET category = TRIM(category),
    merchant = TRIM(merchant),
    ...
```

**3. Null checks**
Ran a full null and empty string check across all columns before analysis:
```sql
SELECT
    SUM(CASE WHEN trans_date_trans_time IS NULL THEN 1 ELSE 0 END) AS date_issues,
    SUM(CASE WHEN amt IS NULL THEN 1 ELSE 0 END) AS amount_issues,
    SUM(CASE WHEN is_fraud IS NULL THEN 1 ELSE 0 END) AS fraud_issues
FROM fraud_clean
```
Result: No nulls found. Data was clean and ready for analysis.

---

## SQL Analysis

### Query 1 — Overall Fraud Rate by Merchant Category
**Question:** What percentage of transactions are fraudulent by category?
```sql
SELECT 
    category,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
    CAST(ROUND(100.0 * SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) AS fraud_rate_pct
FROM fraud_clean
GROUP BY category
ORDER BY fraud_rate_pct DESC
```
**Finding:** shopping_net had the highest fraud rate at 1.76%. No category exceeded 3%.

---

### Query 2 — Average Transaction Amount: Fraud vs Legitimate
**Question:** Do fraudulent transactions differ in value from legitimate ones?
```sql
SELECT 
    is_fraud,
    ROUND(AVG(amt), 2) AS avg_transaction_amount
FROM fraud_clean
GROUP BY is_fraud
```
**Finding:** Average fraud transaction was $531.32 vs $67.67 for legitimate — nearly 8x higher.

---

### Query 3 — Fraud Rate by Time of Day
**Question:** Are certain times of day more associated with fraud?
```sql
SELECT
    CASE
        WHEN DATEPART(hour, trans_date_trans_time) BETWEEN 8 AND 11 THEN 'Morning (8am-12pm)'
        WHEN DATEPART(hour, trans_date_trans_time) BETWEEN 13 AND 15 THEN 'Afternoon (1pm-4pm)'
        WHEN DATEPART(hour, trans_date_trans_time) BETWEEN 17 AND 21 THEN 'Evening (5pm-10pm)'
        ELSE 'Night (11pm-7am)'
    END AS time_of_day,
    COUNT(*) AS total_transactions,
    CAST(ROUND(100.0 * SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) AS fraud_rate_pct
FROM fraud_clean
GROUP BY
    CASE
        WHEN DATEPART(hour, trans_date_trans_time) BETWEEN 8 AND 11 THEN 'Morning (8am-12pm)'
        WHEN DATEPART(hour, trans_date_trans_time) BETWEEN 13 AND 15 THEN 'Afternoon (1pm-4pm)'
        WHEN DATEPART(hour, trans_date_trans_time) BETWEEN 17 AND 21 THEN 'Evening (5pm-10pm)'
        ELSE 'Night (11pm-7am)'
    END
ORDER BY fraud_rate_pct DESC
```
**Finding:** Night transactions (11pm–7am) showed a fraud rate of 1.11% — 10x higher than any daytime period.

---

### Query 4 — Geographic Fraud Rate by State
**Question:** Which states have the highest fraud rates? (Filtered to states with 1,000+ transactions to avoid small sample bias)
```sql
SELECT
    state,
    COUNT(*) AS total_transactions,
    CAST(ROUND(100.0 * SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) AS fraud_rate_pct
FROM fraud_clean
GROUP BY state
HAVING COUNT(*) > 1000
ORDER BY fraud_rate_pct DESC
```
**Finding:** Alaska had the highest fraud rate at 1.70% — more than double Nevada (0.84%). A minimum transaction threshold was applied to exclude statistically unreliable states.

---

### Query 5 — Merchant Anomaly Flags
**Question:** Are any merchants showing unusually high fraud rates above 10%?
```sql
SELECT
    merchant,
    COUNT(*) AS total_transactions,
    CAST(ROUND(100.0 * SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) AS fraud_rate_pct
FROM fraud_clean
GROUP BY merchant
HAVING CAST(ROUND(100.0 * SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) > 10
ORDER BY fraud_rate_pct DESC
```
**Finding:** No merchants exceeded 10%. Highest was Kozey-Boehm at 2.57%. Fraud is systemic across the network — not merchant specific.

---

### Query 6 — Repeat Fraud Victims
**Question:** Which customers have been hit with fraud more than once and are above the average fraud count per customer?
```sql
SELECT
    Full_name,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
    CAST(ROUND(100.0 * SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) AS fraud_rate_pct,
    CASE WHEN SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) > 
        AVG(CAST(SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) AS FLOAT)) OVER ()
        THEN 'Flag' ELSE 'OK'
    END AS priority_flag
FROM fraud_clean
GROUP BY Full_name
ORDER BY fraud_count DESC
```
**Finding:** 754 customers flagged as high priority based on above average fraud frequency.

---

## Dashboard
Built in Power BI with 6 KPI cards, a geographic heat map, merchant table, time of day analysis, and priority flagged customer table.

![Dashboard](dashboard.png)

**Key visuals:**
- **Fraud Risk by Category** — red to green gradient bar chart sorted by fraud rate
- **Top 10 Merchants by Fraud Rate** — sortable table
- **Geographic Map** — white to dark red gradient showing state level fraud rates
- **Fraud Risk by Time of Day** — horizontal bar chart highlighting night spike
- **Priority Flagged Customers** — table with conditional formatting sorted by total fraud cases
- **Key Insights box** — three bullet point summary of top findings

**Slicers:** Year, Category, State — all cross filter every visual on the page

---

## Key Findings
| Finding | Detail |
|---|---|
| Overall Fraud Rate | 0.58% across 1.3M transactions |
| Highest Risk Time | Night (11pm–7am) at 1.11% — 10x daytime |
| Fraud Transaction Value | $531 avg vs $67 for legitimate — 8x higher |
| Highest Risk State | Alaska at 1.70% — double Nevada (0.84%) |
| Merchant Risk | No merchant exceeded 3% — fraud is network wide |
| Flagged Customers | 754 customers flagged for above average fraud exposure |
