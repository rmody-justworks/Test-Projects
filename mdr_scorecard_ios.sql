SELECT
    o.X18_CHARACTER_ID AS "Opportunity ID (18 Character)",
    o.OWNER_FULL_NAME AS "Opportunity Owner",
    ur.USER_ROLE_NAME AS "Owner Role",
    o.OPPORTUNITY_NAME AS "Opportunity Name",
    o.STAGE_NAME AS "Stage",
    o.FISCAL_QUARTER AS "Fiscal Period",
    o.CLOSED_DATE AS "Close Date",
    o.LEAD_SOURCE AS "Lead Source",
    o.OPPORTUNITY_TYPE AS "Type",
    o.CREATED_AT AS "Created Date",
    o.INTERESTED_DATE AS "Date Interested",
    o.DATE_MOVED_TO_EVALUATE_FIT AS "Date Moved To Evaluate Fit",
    o.DATE_MOVED_TO_NEGOTIATE AS "Date Moved To Negotiate",
    o.DATE_MOVED_TO_ONBOARD AS "Date Moved To Onboard",
    o.AGE_AT_CLOSE AS "Age at Close",
    o.OPP_SOURCE AS "Opp Source",
    osu.FIRST_NAME || ' ' || osu.LAST_NAME AS "Sourced By",
    osu_mgr.FIRST_NAME || ' ' || osu_mgr.LAST_NAME AS "Sourced By Manager",
    o.IS_WON AS "Won",
    o.EMPLOYEE_COUNT AS "EE",
    o.CORE_PRODUCT AS "Core Product",
    o.NET_CORE_PRODUCT_ARR AS "Net Core Product ARR",
    o.NET_ARR AS "Total Net ARR",
    pao.FIRST_NAME || ' ' || pao.LAST_NAME AS "Partner Account Owner",
    o.PARTNER_ACCOUNT_NAME AS "Partner Account Name",
    rt.RECORD_TYPE_NAME AS "Opportunity Record Type",
    o.SALES_MODE AS "Sales Mode",
    o.OWNER_MANAGER AS "Opportunity Owner: Manager",
    o.GONG_CL_NOTES AS "Gong: CL Notes",
    o.GONG_CL_REASON AS "Gong: CL Reason",
    o.GONG_CL_REASON_NOTES AS "Gong: CL Reason Details",
    o.GONG_PRIMARY_COMPETITOR AS "Gong: Primary Competitor",
    a.ACCOUNT_NAME AS "Account Name",
    o.ACCOUNT_ID AS "Account ID",

    -- IO Quarter (Fiscal Period based on Date Interested)
    CASE
        WHEN o.INTERESTED_DATE BETWEEN '2025-06-01' AND '2025-08-31' THEN 'Q1-2026'
        WHEN o.INTERESTED_DATE BETWEEN '2025-09-01' AND '2025-11-30' THEN 'Q2-2026'
        WHEN o.INTERESTED_DATE BETWEEN '2025-12-01' AND '2026-02-28' THEN 'Q3-2026'
        WHEN o.INTERESTED_DATE BETWEEN '2026-03-01' AND '2026-05-31' THEN 'Q4-2026'
        WHEN o.INTERESTED_DATE BETWEEN '2026-06-01' AND '2026-08-31' THEN 'Q1-2027'
        WHEN o.INTERESTED_DATE BETWEEN '2026-09-01' AND '2026-11-30' THEN 'Q2-2027'
        WHEN o.INTERESTED_DATE BETWEEN '2026-12-01' AND '2027-02-28' THEN 'Q3-2027'
        WHEN o.INTERESTED_DATE BETWEEN '2027-03-01' AND '2027-05-31' THEN 'Q4-2027'
        WHEN o.INTERESTED_DATE BETWEEN '2027-06-01' AND '2027-08-31' THEN 'Q1-2028'
        WHEN o.INTERESTED_DATE BETWEEN '2027-09-01' AND '2027-11-30' THEN 'Q2-2028'
        WHEN o.INTERESTED_DATE BETWEEN '2027-12-01' AND '2028-02-28' THEN 'Q3-2028'
        WHEN o.INTERESTED_DATE BETWEEN '2028-03-01' AND '2028-05-31' THEN 'Q4-2028'
        ELSE NULL
    END AS "IO Quarter",

    -- Service Mode
    CASE WHEN o.SELF_SERVICE = TRUE THEN 'Self-Service' ELSE 'Managed Sales' END AS "Service Mode",

    -- Lead Source Bucket
    CASE o.LEAD_SOURCE
        WHEN 'Affiliate' THEN 'Affiliate'
        WHEN 'Direct Traffic' THEN 'Direct Traffic'
        WHEN 'Organic Search' THEN 'Organic Search'
        WHEN 'Paid Search' THEN 'Paid Search'
        WHEN 'Paid Social Media' THEN 'Paid Social Media'
        WHEN 'Warm Outbound' THEN 'Warm Outbound'
        ELSE 'Other'
    END AS "Lead Source Bucket"

FROM PROD_SOURCE_DB.SALESFORCE.OPPORTUNITIES o
LEFT JOIN PROD_SOURCE_DB.SALESFORCE.ACCOUNTS a ON o.ACCOUNT_ID = a.ACCOUNT_ID
LEFT JOIN PROD_SOURCE_DB.SALESFORCE.USERS own ON o.OWNER_ID = own.USER_ID
LEFT JOIN PROD_SOURCE_DB.SALESFORCE.USER_ROLES ur ON own.USER_ROLE_ID = ur.USER_ROLE_ID
JOIN PROD_SOURCE_DB.SALESFORCE.USERS osu ON o.OPP_SOURCE_USER_ID = osu.USER_ID
LEFT JOIN PROD_SOURCE_DB.SALESFORCE.USERS osu_mgr ON osu.MANAGER_ID = osu_mgr.USER_ID
LEFT JOIN PROD_SOURCE_DB.SALESFORCE.USERS pao ON o.PARTNER_ACCOUNT_OWNER = pao.USER_ID
LEFT JOIN PROD_SOURCE_DB.SALESFORCE.RECORD_TYPES rt ON o.RECORD_TYPE_ID = rt.RECORD_TYPE_ID
WHERE o.IS_DELETED = FALSE
  AND o.INTERESTED_DATE BETWEEN '2025-06-01' AND '2027-05-31'
  AND rt.RECORD_TYPE_NAME != 'Parent'
  AND o.OPPORTUNITY_TYPE NOT IN ('Partner', 'Test')
  AND osu.FIRST_NAME || ' ' || osu.LAST_NAME IN ('Natasha Karlin','Ruznelly Fabre','Molly Casey','Amelia Wilson','Ryan Harris')
ORDER BY o.INTERESTED_DATE DESC;
