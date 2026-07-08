SELECT
    l.CREATED_DATE                              AS "Create Date",
    l.FIRST_NAME                                AS "First Name",
    l.LAST_NAME                                 AS "Last Name",
    l.COMPANY_NAME                              AS "Company / Account",
    l.NUMBER_OF_EMPLOYEES                       AS "No. of Employees",
    l.STATE                                     AS "State/Province",
    l.LAST_ACTIVITY_DATE                        AS "Last Activity",
    l.LEAD_SOURCE                               AS "Lead Source",
    l.LEAD_SOURCE_DETAIL                        AS "Lead Source Detail",
    l.DISQUALIFICATION_REASON                   AS "Disqualification Reason",
    l.OWNER_FULL_NAME                           AS "Lead Owner",

    l.FIRST_NAME || ' ' || l.LAST_NAME          AS "Final Lead Name",

    CASE l.DISQUALIFICATION_REASON
        WHEN 'Bogus' THEN 'Bogus'
        WHEN 'Customer/Duplicate' THEN 'Customer/Duplicate'
        WHEN 'Industry' THEN 'Industry'
        WHEN 'Size' THEN 'Size'
        WHEN 'Location' THEN 'Location'
        WHEN 'WC' THEN 'WC'
        WHEN 'Not Interested' THEN 'Not Interested'
        WHEN 'Missing Feature' THEN 'Missing Feature'
        WHEN 'No Response' THEN 'No Response'
        ELSE 'Other'
    END                                         AS "Final DQ Reason",

    CASE
        WHEN l.CREATED_DATE BETWEEN '2025-06-01' AND '2025-08-31' THEN 'Q1-2026'
        WHEN l.CREATED_DATE BETWEEN '2025-09-01' AND '2025-11-30' THEN 'Q2-2026'
        WHEN l.CREATED_DATE BETWEEN '2025-12-01' AND '2026-02-28' THEN 'Q3-2026'
        WHEN l.CREATED_DATE BETWEEN '2026-03-01' AND '2026-05-31' THEN 'Q4-2026'
        WHEN l.CREATED_DATE BETWEEN '2026-06-01' AND '2026-08-31' THEN 'Q1-2027'
        WHEN l.CREATED_DATE BETWEEN '2026-09-01' AND '2026-11-30' THEN 'Q2-2027'
        WHEN l.CREATED_DATE BETWEEN '2026-12-01' AND '2027-02-28' THEN 'Q3-2027'
        WHEN l.CREATED_DATE BETWEEN '2027-03-01' AND '2027-05-31' THEN 'Q4-2027'
        WHEN l.CREATED_DATE BETWEEN '2027-06-01' AND '2027-08-31' THEN 'Q1-2028'
        WHEN l.CREATED_DATE BETWEEN '2027-09-01' AND '2027-11-30' THEN 'Q2-2028'
        WHEN l.CREATED_DATE BETWEEN '2027-12-01' AND '2028-02-28' THEN 'Q3-2028'
        WHEN l.CREATED_DATE BETWEEN '2028-03-01' AND '2028-05-31' THEN 'Q4-2028'
        ELSE NULL
    END                                         AS "Fiscal Period",

    CASE
        WHEN EXISTS (
            SELECT 1 FROM PROD_SOURCE_DB.SALESFORCE.LEAD_HISTORY lh
            WHERE lh.LEAD_ID = l.LEAD_ID
              AND lh.IS_DELETED = FALSE
              AND lh.CREATED_AT >= '2025-06-01'
        )
        THEN CASE WHEN l.NOT_INBOUND_SELF_SERVICE = 1 THEN 'Managed Sales' ELSE 'Self-Service' END
        ELSE 'Managed Services'
    END                                         AS "Service"

FROM PROD_SOURCE_DB.SALESFORCE.LEADS l
WHERE l.IS_DELETED = FALSE
  AND l.CREATED_DATE BETWEEN '2025-06-01' AND '2027-05-31'
  AND l.OWNER_FULL_NAME IN ('Natasha Karlin','Ruznelly Fabre','Molly Casey','Amelia Wilson','Ryan Harris')
  AND l.LEAD_STATUS != 'Distributed'
  AND l.IS_CONVERTED = FALSE
  AND l.COMPANY_NAME NOT IN ('N/A [Drift]', '[[Unknown]]')
  AND (l.SALESLOFT1_MOST_RECENT_CADENCE_NAME IS NULL OR l.SALESLOFT1_MOST_RECENT_CADENCE_NAME != 'Unify Test 2.0')
  AND (l.UNIFY_TAG IS NULL OR l.UNIFY_TAG = '')
  AND l.COMPANY_NAME NOT LIKE '%Marsh McClennan%'
  AND (l.LEAD_SOURCE_DETAIL_DESCRIPTION IS NULL OR l.LEAD_SOURCE_DETAIL_DESCRIPTION != 'fy26_events_central_dallas_SHRMTalent2026_apr19')
ORDER BY l.CREATED_DATE DESC;
