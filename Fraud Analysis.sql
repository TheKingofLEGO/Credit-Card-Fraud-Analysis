/* SQL Task:
1) Fraud Rate Overview — What % of transactions are fraudulent? Break it down by merchant category.
2) Transaction Patterns — What's the average transaction amount for fraud vs. non-fraud? Any time-of-day patterns?
3) High Risk Segments — Which age groups or geographies show the highest fraud rates?
4) Anomaly Flags — Flag any merchants with a fraud rate above 10% — these need to go to the fraud team.
5) Repeat Fraud Victims — Identify any cardholders who have been hit with fraud more than once. 
Include their name, how many total transactions they have, how many were fraud, and their personal fraud rate. 
Order by most fraud incidents first.
*/
SELECT * FROM fraud_clean;

--1) Fraud Rate Overview — What % of transactions are fraudulent? Break it down by merchant category.
SELECT
    Category,
    COUNT(*) AS Total_Transactions, --tells how many orders
    SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) AS Fraud_Count, --How many of those orders are frauds
    CAST(ROUND(100.0 * SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) AS Fraud_Rate_Pct, --the rate of fraud risk in each group
    CAST(ROUND(100.0 * SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) /
        SUM(SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END)) OVER (), 2) AS DECIMAL(5,2)) AS Share_of_Total_Fraud_Pct --how much the % contributes to the whole company.
FROM fraud_clean
GROUP BY Category
ORDER BY Fraud_Rate_Pct DESC

--2) Transaction Patterns — What's the average transaction amount for fraud vs. non-fraud? Any time-of-day patterns?
--Avg transaction abount between fraud and non-fraud transation
SELECT
    Is_fraud,
    COUNT(*) AS Total_Transactions, --tells how many orders
    CAST(AVG(Amount) AS DECIMAL(10,2)) AS Avg_Transaction_Amount,
    CAST(MIN(Amount) AS DECIMAL(10,2)) AS Min_Amount,
    CAST(MAX(Amount) AS DECIMAL(10,2)) AS Max_Amount
FROM fraud_clean
GROUP BY Is_fraud
ORDER BY Is_fraud DESC

--Time of day pattern.
SELECT
    CASE
        WHEN DATEPART(hour, Date) BETWEEN 8 AND 11 THEN 'Morning (8am-12pm)'
        WHEN DATEPART(hour, Date) BETWEEN 13 AND 15 THEN 'Afternoon (1pm-4pm)'
        WHEN DATEPART(hour, Date) BETWEEN 17 AND 21 THEN 'Evening (5pm-10pm)'
        ELSE 'Night (11pm-7am)'
    END AS Time_of_Day,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) AS Fraud_Count,--How many of those orders are frauds
    CAST(ROUND(100.0 * SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) AS Fraud_Rate_Pct, --the rate of fraud risk in each group
    CAST(AVG(Amount) AS DECIMAL(10,2)) AS Avg_Transaction_Amount
FROM fraud_clean
GROUP BY 
    CASE 
        WHEN DATEPART(hour, Date) BETWEEN 8 AND 11 THEN 'Morning (8am-12pm)'
        WHEN DATEPART(hour, Date) BETWEEN 13 AND 15 THEN 'Afternoon (1pm-4pm)'
        WHEN DATEPART(hour, Date) BETWEEN 17 AND 21 THEN 'Evening (5pm-10pm)'
        ELSE 'Night (11pm-7am)'
    END
ORDER BY Fraud_Rate_Pct DESC

--3) High Risk Segments — Which age groups or geographies show the highest fraud rates?
--state
SELECT
    State,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) AS Fraud_Count, --How many orders were fraud
    CAST(ROUND(100.0 * SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) AS Fraud_Rate_Pct --the rate of fraud risk in each group
FROM Fraud_clean
GROUP BY state
HAVING COUNT(*) > 1000 
ORDER BY CAST(ROUND(100.0 * SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) DESC;

--Age
SELECT
    CASE
        WHEN DATEDIFF(year, DOB, GETDATE()) BETWEEN 18 AND 30 THEN '18-30'
        WHEN DATEDIFF(year, DOB, GETDATE()) BETWEEN 31 AND 45 THEN '31-45'
        WHEN DATEDIFF(year, DOB, GETDATE()) BETWEEN 46 AND 60 THEN '46-60'
        ELSE '60+'
    END AS Age_Group,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) AS Fraud_Count,
    CAST(ROUND(100.0 * SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) AS Fraud_Rate_Pct --the rate of fraud risk in each group
FROM fraud_clean
GROUP BY
    CASE
        WHEN DATEDIFF(year, DOB, GETDATE()) BETWEEN 18 AND 30 THEN '18-30'
        WHEN DATEDIFF(year, DOB, GETDATE()) BETWEEN 31 AND 45 THEN '31-45'
        WHEN DATEDIFF(year, DOB, GETDATE()) BETWEEN 46 AND 60 THEN '46-60'
        ELSE '60+'
    END
ORDER BY Fraud_Rate_Pct DESC

--4) Anomaly Flags — Flag any merchants with a fraud rate above 10% — these need to go to the fraud team.
--No merchant went above 10%.
SELECT
    merchant,
    SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) AS Fraud_Count,
    CAST(ROUND(100.0 * SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) AS Fraud_Rate_Pct --the rate of fraud risk in each group
FROM fraud_clean
GROUP BY merchant
ORDER BY CAST(ROUND(100.0 * SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) DESC;

/* 5) Repeat Fraud Victims — Identify any cardholders who have been hit with fraud more than once. 
Include their name, how many total transactions they have, how many were fraud, and their personal fraud rate. 
Order by most fraud incidents first.

Also while you're at it, flag anyone whose fraud count is above the average fraud count per customer 
— those are your highest priority cases.
*/
--avg fraud count
SELECT AVG(CAST(Fraud_Count AS FLOAT)) AS Avg_Fraud_Count
FROM (
    SELECT 
        Full_name,
        SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) AS Fraud_Count 
    FROM fraud_clean
    GROUP BY Full_name
) AS subquery

--Victims
SELECT
    Full_name,
    Total_Transactions,
    Fraud_Count,
    Fraud_Rate_Pct,
    CASE
        WHEN Fraud_Count > AVG(CAST(Fraud_Count AS FLOAT)) OVER () THEN 'Flag'
        ELSE 'OK'
    END AS Priority_Flag
FROM (
    SELECT
        Full_name,
        SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) AS Fraud_Count,
        CAST(ROUND(100.0 * SUM(CASE WHEN Is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5,2)) AS Fraud_Rate_Pct,--the rate of fraud risk in each group
        COUNT(*) AS Total_Transactions
    FROM fraud_clean
    GROUP BY Full_name
) AS customer_summary
ORDER BY Fraud_Count DESC