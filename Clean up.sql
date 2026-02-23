SELECT
    is_fraud                                  AS Is_Fraud,
    first + ' ' + last                        AS Full_Name,
    REPLACE(merchant, 'fraud_', '')           AS Merchant,
    trans_date_trans_time                     AS Date,
    category                                  AS Category,
    ROUND(amt, 2)                             AS Amount,
    gender                                    AS Gender,
    city                                      AS City,
    state                                     AS State,
    city_pop                                  AS Population,
    job                                       AS Job,
    ROUND(lat, 4)                             AS Lat,
    ROUND(long, 4)                            AS Long,
    ROUND(merch_lat, 4)                       AS Merchant_Lat,
    ROUND(merch_long, 4)                      AS Merchant_Long,
    dob                                       AS DOB,
    trans_num                                 AS Trans_ID,
    unix_time                                 AS Unix_Time

INTO fraud_clean_2
FROM fraud