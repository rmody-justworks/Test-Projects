WITH lead_history_source AS (
    SELECT DISTINCT
        l.FIRST_NAME || ' ' || l.LAST_NAME AS full_name,
        CASE l.LEAD_SOURCE
            WHEN 'Affiliate' THEN 'Affiliate'
            WHEN 'Direct Traffic' THEN 'Direct Traffic'
            WHEN 'Organic Search' THEN 'Organic Search'
            WHEN 'Paid Search' THEN 'Paid Search'
            WHEN 'Paid Social Media' THEN 'Paid Social Media'
            WHEN 'Warm Outbound' THEN 'Warm Outbound'
            ELSE 'Other'
        END AS lead_source_bucket
    FROM PROD_SOURCE_DB.SALESFORCE.LEAD_HISTORY lh
    JOIN PROD_SOURCE_DB.SALESFORCE.LEADS l ON lh.LEAD_ID = l.LEAD_ID
    WHERE lh.IS_DELETED = FALSE
      AND lh.CREATED_AT >= '2025-06-01'
      AND l.OWNER_FULL_NAME IN ('Natasha Karlin','Ruznelly Fabre','Molly Casey','Amelia Wilson','Ryan Harris')
      AND l.LEAD_SOURCE NOT IN ('Content Syndication', 'Event')
),

io_lookup AS (
    SELECT
        o.ACCOUNT_ID,
        osu.FIRST_NAME || ' ' || osu.LAST_NAME AS sourced_by,
        a.ACCOUNT_NAME,
        CASE WHEN o.SELF_SERVICE = TRUE THEN 'Self-Service' ELSE 'Managed Sales' END AS service_mode
    FROM PROD_SOURCE_DB.SALESFORCE.OPPORTUNITIES o
    JOIN PROD_SOURCE_DB.SALESFORCE.USERS osu ON o.OPP_SOURCE_USER_ID = osu.USER_ID
    LEFT JOIN PROD_SOURCE_DB.SALESFORCE.ACCOUNTS a ON o.ACCOUNT_ID = a.ACCOUNT_ID
    LEFT JOIN PROD_SOURCE_DB.SALESFORCE.RECORD_TYPES rt ON o.RECORD_TYPE_ID = rt.RECORD_TYPE_ID
    WHERE o.IS_DELETED = FALSE
      AND o.INTERESTED_DATE BETWEEN '2025-06-01' AND '2027-05-31'
      AND rt.RECORD_TYPE_NAME != 'Parent'
      AND o.OPPORTUNITY_TYPE NOT IN ('Partner', 'Test')
    QUALIFY ROW_NUMBER() OVER (PARTITION BY o.ACCOUNT_ID, osu.FIRST_NAME || ' ' || osu.LAST_NAME ORDER BY o.INTERESTED_DATE DESC) = 1
),

activity_daily AS (
    SELECT
        CASE
            WHEN LEFT(t.WHO_ID, 3) = '003' AND c.NAME IS NOT NULL THEN c.NAME
            WHEN LEFT(t.WHO_ID, 3) = '00Q' THEN ld.FIRST_NAME || ' ' || ld.LAST_NAME
            ELSE NULL
        END AS final_lead_name,
        u.FIRST_NAME || ' ' || u.LAST_NAME AS assigned,
        t.ACTIVITY_DATE,
        t.TYPE AS activity_type,
        t.SALESLOFT_TYPE
    FROM PROD_SOURCE_DB.SALESFORCE.TASKS t
    LEFT JOIN PROD_SOURCE_DB.SALESFORCE.CONTACTS c ON t.WHO_ID = c.CONTACT_ID AND LEFT(t.WHO_ID, 3) = '003'
    LEFT JOIN PROD_SOURCE_DB.SALESFORCE.LEADS ld ON t.WHO_ID = ld.LEAD_ID AND LEFT(t.WHO_ID, 3) = '00Q'
    LEFT JOIN PROD_SOURCE_DB.SALESFORCE.USERS u ON t.OWNER_ID = u.USER_ID
    WHERE t.IS_DELETED = FALSE
      AND t.STATUS = 'Completed'
      AND t.ACTIVITY_DATE BETWEEN '2025-06-01' AND '2027-05-31'
      AND t.TYPE IN ('Call', 'Email')
      AND u.FIRST_NAME || ' ' || u.LAST_NAME IN ('Natasha Karlin','Ruznelly Fabre','Molly Casey','Amelia Wilson','Ryan Harris')
),

meetings_base AS (
    SELECT
        e.EVENT_ID,
        e.CREATED_DATE,
        e.ACTIVITY_DATE AS meeting_date,
        a.ACCOUNT_NAME AS company_account,
        o.OPPORTUNITY_NAME,
        CASE WHEN LEFT(e.WHO_ID, 3) = '003' THEN c.NAME ELSE NULL END AS contact_name,
        CASE WHEN LEFT(e.WHO_ID, 3) = '00Q' THEN ld.FIRST_NAME || ' ' || ld.LAST_NAME ELSE NULL END AS lead_name_raw,
        e.SUBJECT,
        u.FIRST_NAME || ' ' || u.LAST_NAME AS assigned,
        e.SHOW_AS AS priority,
        CASE WHEN e.IS_COMPLETE = TRUE THEN 'Completed' ELSE 'Open' END AS status,
        e.TYPE AS task,
        e.ACCOUNT_ID,
        creator.FIRST_NAME || ' ' || creator.LAST_NAME AS created_by,
        e.CREATED_BY_MANAGER,
        e.STARTED_AT AS due_time,
        e.TYPE AS activity_type,
        rt.RECORD_TYPE_NAME AS record_type,
        e.ASSIGNED_MANAGER,
        e.IS_NO_SHOW_CP AS no_show,
        COALESCE(
            CASE WHEN LEFT(e.WHO_ID, 3) = '003' THEN c.NAME ELSE NULL END,
            CASE WHEN LEFT(e.WHO_ID, 3) = '00Q' THEN ld.FIRST_NAME || ' ' || ld.LAST_NAME ELSE NULL END
        ) AS lead_name,
        MAX(e.ACTIVITY_DATE) OVER (
            PARTITION BY a.ACCOUNT_NAME
            ORDER BY e.ACTIVITY_DATE, e.CREATED_DATE
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS prev_max_date
    FROM PROD_SOURCE_DB.SALESFORCE.EVENTS e
    LEFT JOIN PROD_SOURCE_DB.SALESFORCE.ACCOUNTS a ON e.ACCOUNT_ID = a.ACCOUNT_ID
    LEFT JOIN PROD_SOURCE_DB.SALESFORCE.OPPORTUNITIES o ON e.OPPORTUNITY_ID = o.OPPORTUNITY_ID
    LEFT JOIN PROD_SOURCE_DB.SALESFORCE.CONTACTS c ON e.WHO_ID = c.CONTACT_ID AND LEFT(e.WHO_ID, 3) = '003'
    LEFT JOIN PROD_SOURCE_DB.SALESFORCE.LEADS ld ON e.WHO_ID = ld.LEAD_ID AND LEFT(e.WHO_ID, 3) = '00Q'
    LEFT JOIN PROD_SOURCE_DB.SALESFORCE.USERS u ON e.OWNER_ID = u.USER_ID
    LEFT JOIN PROD_SOURCE_DB.SALESFORCE.USERS creator ON e.CREATED_BY_ID = creator.USER_ID
    LEFT JOIN PROD_SOURCE_DB.SALESFORCE.RECORD_TYPES rt ON e.RECORD_TYPE_ID = rt.RECORD_TYPE_ID
    WHERE e.IS_DELETED = FALSE
      AND e.CREATED_DATE BETWEEN '2025-06-01' AND '2027-05-31'
      AND e.CREATED_BY_MANAGER IN ('Maddy Jaworski', 'William Lynam', 'Giuliana Cerullo', 'Rafi Attias')
      AND creator.FIRST_NAME || ' ' || creator.LAST_NAME IN ('Natasha Karlin','Ruznelly Fabre','Molly Casey','Amelia Wilson','Ryan Harris')
),

meeting_activity AS (
    SELECT
        mb.EVENT_ID,
        COUNT(CASE WHEN ad.activity_type = 'Call' THEN 1 END) AS call_count,
        COUNT(CASE WHEN ad.activity_type = 'Email' AND (ad.SALESLOFT_TYPE IS NULL OR ad.SALESLOFT_TYPE != 'Reply') THEN 1 END) AS email_count
    FROM meetings_base mb
    LEFT JOIN activity_daily ad
        ON ad.final_lead_name = mb.lead_name
        AND ad.assigned = mb.assigned
        AND ad.ACTIVITY_DATE BETWEEN mb.meeting_date AND DATEADD('day', 7, mb.meeting_date)
    GROUP BY mb.EVENT_ID
)

SELECT
    mb.CREATED_DATE                             AS "Created Date",
    mb.meeting_date                             AS "Date",
    mb.company_account                          AS "Company / Account",
    mb.OPPORTUNITY_NAME                         AS "Opportunity",
    mb.contact_name                             AS "Contact",
    mb.lead_name_raw                            AS "Lead",
    mb.SUBJECT                                  AS "Subject",
    mb.assigned                                 AS "Assigned",
    mb.priority                                 AS "Priority",
    mb.status                                   AS "Status",
    mb.task                                     AS "Task",
    mb.ACCOUNT_ID                               AS "Account ID",
    mb.created_by                               AS "Created By",
    mb.CREATED_BY_MANAGER                       AS "Created by Manager",
    mb.due_time                                 AS "Due Time",
    mb.activity_type                            AS "Activity Type",
    mb.record_type                              AS "Type",
    mb.ASSIGNED_MANAGER                         AS "Signed Manager",
    mb.no_show                                  AS "No Show",

    -- Column T: Account Count
    COUNT(*) OVER (PARTITION BY mb.company_account) AS "Account Count",

    -- Column U: Unique / Re-Engaged (TRUE if first occurrence OR date >= prev + 6 months)
    CASE
        WHEN mb.prev_max_date IS NULL THEN TRUE
        WHEN mb.meeting_date >= DATEADD('month', 6, mb.prev_max_date) THEN TRUE
        ELSE FALSE
    END                                         AS "Unique / Re-Engaged",

    -- Column V: Re-Engaged (TRUE if NOT first AND date >= prev + 6 months)
    CASE
        WHEN mb.prev_max_date IS NOT NULL AND mb.meeting_date >= DATEADD('month', 6, mb.prev_max_date) THEN TRUE
        ELSE FALSE
    END                                         AS "Re-Engaged",

    -- Column W: Fiscal Period
    CASE
        WHEN mb.CREATED_DATE::DATE BETWEEN '2025-06-01' AND '2025-08-31' THEN 'Q1-2026'
        WHEN mb.CREATED_DATE::DATE BETWEEN '2025-09-01' AND '2025-11-30' THEN 'Q2-2026'
        WHEN mb.CREATED_DATE::DATE BETWEEN '2025-12-01' AND '2026-02-28' THEN 'Q3-2026'
        WHEN mb.CREATED_DATE::DATE BETWEEN '2026-03-01' AND '2026-05-31' THEN 'Q4-2026'
        WHEN mb.CREATED_DATE::DATE BETWEEN '2026-06-01' AND '2026-08-31' THEN 'Q1-2027'
        WHEN mb.CREATED_DATE::DATE BETWEEN '2026-09-01' AND '2026-11-30' THEN 'Q2-2027'
        WHEN mb.CREATED_DATE::DATE BETWEEN '2026-12-01' AND '2027-02-28' THEN 'Q3-2027'
        WHEN mb.CREATED_DATE::DATE BETWEEN '2027-03-01' AND '2027-05-31' THEN 'Q4-2027'
        WHEN mb.CREATED_DATE::DATE BETWEEN '2027-06-01' AND '2027-08-31' THEN 'Q1-2028'
        WHEN mb.CREATED_DATE::DATE BETWEEN '2027-09-01' AND '2027-11-30' THEN 'Q2-2028'
        WHEN mb.CREATED_DATE::DATE BETWEEN '2027-12-01' AND '2028-02-28' THEN 'Q3-2028'
        WHEN mb.CREATED_DATE::DATE BETWEEN '2028-03-01' AND '2028-05-31' THEN 'Q4-2028'
        ELSE NULL
    END                                         AS "Fiscal Period",

    -- Column X: IO (Account Name from IOs matched on Account ID + Created By)
    io.account_name                             AS "IO",

    -- Column Y: Service (Service Mode from IOs match)
    io.service_mode                             AS "Service",

    -- Column Z: Lead Name (coalesce Contact/Lead)
    mb.lead_name                                AS "Lead Name",

    -- Column AA: No Show Flow Deadline (Date + 7 days)
    DATEADD('day', 7, mb.meeting_date)          AS "No Show Flow Deadline",

    -- Column AB: Calls after meeting (within 7 days, same lead + assigned)
    COALESCE(ma.call_count, 0)                  AS "Calls After Meeting",

    -- Column AC: Emails after meeting (within 7 days, same lead + assigned, excl Reply)
    COALESCE(ma.email_count, 0)                 AS "Emails After Meeting",

    -- Column AD: No Show follow-up met threshold (thresholds from Leads Directed - TBD)
    CASE
        WHEN mb.no_show = TRUE THEN
            CASE WHEN COALESCE(ma.call_count, 0) >= 1 AND COALESCE(ma.email_count, 0) >= 1 THEN TRUE ELSE FALSE END
        ELSE NULL
    END                                         AS "No Show Follow-Up Met",

    -- Column AE: Lead Source Bucket from Lead History
    COALESCE(lhs_contact.lead_source_bucket, lhs_lead.lead_source_bucket, 'Other') AS "Lead Source Bucket"

FROM meetings_base mb
LEFT JOIN io_lookup io
    ON mb.ACCOUNT_ID = io.ACCOUNT_ID
    AND mb.created_by = io.sourced_by
LEFT JOIN lead_history_source lhs_contact ON mb.contact_name = lhs_contact.full_name
LEFT JOIN lead_history_source lhs_lead ON mb.lead_name_raw = lhs_lead.full_name
LEFT JOIN meeting_activity ma ON mb.EVENT_ID = ma.EVENT_ID
ORDER BY mb.CREATED_DATE DESC;
