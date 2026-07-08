SELECT
    l.OWNER_FULL_NAME AS "Lead Owner",
    edited_by.FIRST_NAME || ' ' || edited_by.LAST_NAME AS "Edited By",
    lh.FIELD AS "Field/Event",
    lh.OLD_VALUE AS "Old Value",
    lh.NEW_VALUE AS "New Value",
    lh.CREATED_AT AS "Edit Date",
    l.FIRST_NAME AS "First Name",
    l.LAST_NAME AS "Last Name",
    l.LEAD_STATUS AS "Lead Status",
    l.LEAD_SOURCE AS "Lead Source",
    ur.USER_ROLE_NAME AS "Edited By Role",
    l.MQL_DATE AS "Date of MQL",
    l.HAS_SELF_SERVICE_LEAD AS "Self Service Lead",
    l.NOT_INBOUND_SELF_SERVICE AS "Not Inbound Self Service",
    lh.CREATED_AT::DATE AS "Edit Date Parsed",
    CASE WHEN l.MQL_DATE = lh.CREATED_AT::DATE THEN TRUE ELSE FALSE END AS "MQL",
    l.FIRST_NAME || ' ' || l.LAST_NAME AS "Full Name",
    CASE l.LEAD_SOURCE
        WHEN 'Affiliate' THEN 'Affiliate'
        WHEN 'Direct Traffic' THEN 'Direct Traffic'
        WHEN 'Organic Search' THEN 'Organic Search'
        WHEN 'Paid Search' THEN 'Paid Search'
        WHEN 'Paid Social Media' THEN 'Paid Social Media'
        WHEN 'Warm Outbound' THEN 'Warm Outbound'
        ELSE 'Other'
    END AS "Lead Source Bucket",
    CASE WHEN l.NOT_INBOUND_SELF_SERVICE = 1 THEN 'Managed Sales' ELSE 'Self-Service' END AS "Service Mode"
FROM PROD_SOURCE_DB.SALESFORCE.LEAD_HISTORY lh
JOIN PROD_SOURCE_DB.SALESFORCE.LEADS l ON lh.LEAD_ID = l.LEAD_ID
LEFT JOIN PROD_SOURCE_DB.SALESFORCE.USERS edited_by ON lh.CREATED_BY_ID = edited_by.USER_ID
LEFT JOIN PROD_SOURCE_DB.SALESFORCE.USER_ROLES ur ON edited_by.USER_ROLE_ID = ur.USER_ROLE_ID
WHERE lh.IS_DELETED = FALSE
  AND lh.CREATED_AT >= '2025-06-01 00:00:00'
  AND l.OWNER_FULL_NAME IN ('Natasha Karlin','Ruznelly Fabre','Molly Casey','Amelia Wilson','Ryan Harris')
  AND l.LEAD_SOURCE NOT IN ('Content Syndication', 'Event')
ORDER BY lh.CREATED_AT DESC;
