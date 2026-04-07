-- =============================================================================
-- setup_helpdesk_db.sql
-- Creates and populates the helpdesk schema for LangExtract Workshop Scenario 3
-- Run as: psql -U postgres -d helpdesk -f setup_helpdesk_db.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Schema
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS helpdesk;

-- -----------------------------------------------------------------------------
-- Source table — raw incoming tickets (PDI reads from here)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS helpdesk.tickets CASCADE;

CREATE TABLE helpdesk.tickets (
    ticket_id    VARCHAR(20)  PRIMARY KEY,
    ticket_text  TEXT         NOT NULL,
    created_at   TIMESTAMP    NOT NULL DEFAULT NOW(),
    processed    SMALLINT     NOT NULL DEFAULT 0   -- 0 = pending, 1 = processed
);

-- -----------------------------------------------------------------------------
-- Target table — structured extractions (PDI writes here)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS helpdesk.ticket_triage CASCADE;

CREATE TABLE helpdesk.ticket_triage (
    ticket_id       VARCHAR(20)  PRIMARY KEY,
    issue_type      VARCHAR(100),   -- inferred category e.g. "access issue"
    affected_system VARCHAR(100),   -- application or service name
    urgency         VARCHAR(50),    -- Normal / High / Critical
    submitter       VARCHAR(100),   -- name extracted from ticket
    error_code      VARCHAR(50),    -- specific error code if present
    processed_at    TIMESTAMP       NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- Escalation table — Critical urgency tickets routed here by Filter Rows step
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS helpdesk.escalations CASCADE;

CREATE TABLE helpdesk.escalations (
    ticket_id       VARCHAR(20)  PRIMARY KEY,
    issue_type      VARCHAR(100),
    affected_system VARCHAR(100),
    urgency         VARCHAR(50),
    submitter       VARCHAR(100),
    error_code      VARCHAR(50),
    escalated_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- Sample tickets — 20 rows covering all 5 extraction classes
-- Mix of urgency levels, systems, error codes, and submitter formats
-- Designed to exercise the full extraction pipeline
-- -----------------------------------------------------------------------------
INSERT INTO helpdesk.tickets (ticket_id, ticket_text, created_at) VALUES

-- Access issues
('T-1001',
 'Hi, I cannot log into the VPN since this morning. Error code: VPN-403. '
 'Completely blocking me from working remotely. — Jane Smith, Finance',
 NOW() - INTERVAL '5 hours'),

('T-1002',
 'Urgent! SharePoint is refusing my login credentials. Getting ERR-401 on every attempt. '
 'I have a client presentation in 2 hours and need my files. — Mark Davies, Sales',
 NOW() - INTERVAL '4 hours 50 minutes'),

('T-1003',
 'Cannot access Confluence. Error ERR-502. Urgent! — Alice, DevOps',
 NOW() - INTERVAL '4 hours 30 minutes'),

-- Performance / outage issues
('T-1004',
 'Jira is extremely slow, almost unusable. Pages taking 30+ seconds to load. '
 'No specific error code but it started after the maintenance window last night. '
 'Not urgent but affecting productivity. — Tom Reeves, Engineering',
 NOW() - INTERVAL '4 hours'),

('T-1005',
 'CRITICAL — Production database is down. Error ORA-12541: TNS no listener. '
 'All backend services are failing. Entire platform affected. '
 'Raising as P1. — Sarah Connor, Platform Engineering',
 NOW() - INTERVAL '3 hours 45 minutes'),

-- Software / installation issues
('T-1006',
 'Adobe Acrobat keeps crashing when I try to open PDFs larger than 50MB. '
 'Error: ACRO-1023. Happened after the automatic update yesterday. '
 'Low priority but blocking contract reviews. — David Park, Legal',
 NOW() - INTERVAL '3 hours 30 minutes'),

('T-1007',
 'Python environment broken after IT pushed a new image to my laptop. '
 'pip install fails with ERROR: Could not find a version that satisfies the requirement. '
 'Urgent — I have a data pipeline deployment today. — Priya Sharma, Data Engineering',
 NOW() - INTERVAL '3 hours'),

-- Email / communication issues
('T-1008',
 'Outlook is not syncing emails. Last sync was 6 hours ago. '
 'No error message visible. Tried restarting — no change. — Bob Wilson, HR',
 NOW() - INTERVAL '2 hours 45 minutes'),

('T-1009',
 'Teams calls keep dropping after exactly 45 minutes. Error code MS-TEAMS-408. '
 'Happening to everyone in our building — suspected network issue. '
 'Critical for our daily standups. — Lisa Chen, Product',
 NOW() - INTERVAL '2 hours 30 minutes'),

-- Printer / hardware
('T-1010',
 'Office printer on floor 3 showing error E-502-PAPER-JAM but there is no paper jam. '
 'Tried clearing and restarting. Still stuck. Low urgency. — Karen White, Admin',
 NOW() - INTERVAL '2 hours'),

-- Security / permissions
('T-1011',
 'URGENT — I received a suspicious phishing email appearing to come from our CEO. '
 'Have not clicked any links. Flagging immediately for the security team. '
 'Ticket raised by: James Thornton, Compliance',
 NOW() - INTERVAL '1 hour 45 minutes'),

('T-1012',
 'My account has been locked out after too many failed attempts. '
 'Error: LDAP-49 account locked. Need urgent reset — I am in the middle of a go-live. '
 '— Mei Zhang, DevOps',
 NOW() - INTERVAL '1 hour 30 minutes'),

-- Cloud / infrastructure
('T-1013',
 'AWS S3 bucket returning AccessDenied errors since the IAM policy update yesterday. '
 'Error: S3-403-AccessDenied. Affecting our nightly ETL jobs. '
 'High priority — data pipelines failing. — Ravi Patel, Cloud Engineering',
 NOW() - INTERVAL '1 hour 15 minutes'),

('T-1014',
 'Kubernetes pods in the staging namespace keep crashing with OOMKilled. '
 'Error: K8S-OOM-137. Memory limits may need adjusting. '
 'Not urgent — staging only. — Chris Evans, Platform',
 NOW() - INTERVAL '1 hour'),

-- ERP / business apps
('T-1015',
 'SAP is showing a dump error when I try to post invoices. '
 'Dump code: ABAP-RABAX-00. Finance month-end close is today — CRITICAL. '
 '— Helen Ford, Finance',
 NOW() - INTERVAL '50 minutes'),

('T-1016',
 'Salesforce Lightning is not loading opportunity records. '
 'Getting a generic "Something went wrong" with code SF-UI-500. '
 'Affecting the whole sales team. High urgency — quarter end tomorrow. '
 '— Nathan Brooks, Sales Operations',
 NOW() - INTERVAL '40 minutes'),

-- Network
('T-1017',
 'WiFi dropping every 20 minutes in meeting room B4. '
 'Error code: WIFI-DHCP-TIMEOUT. Happening to anyone who connects. '
 'Board meeting tomorrow in that room — please fix urgently. — Anna Ross, EA',
 NOW() - INTERVAL '30 minutes'),

-- Monitoring / alerting
('T-1018',
 'PagerDuty alerts are not firing for our production monitors. '
 'Last alert received 12 hours ago despite known incidents. '
 'Error in PagerDuty logs: PD-WEBHOOK-408. Critical — we are flying blind. '
 '— Oliver James, SRE',
 NOW() - INTERVAL '20 minutes'),

-- Backup / recovery
('T-1019',
 'Veeam backup job failed overnight with error VBR-E-0303. '
 'Last successful backup was 48 hours ago. Low urgency for now '
 'but needs resolving before end of week. — Susan Gray, IT Ops',
 NOW() - INTERVAL '10 minutes'),

-- Generic / unclear (tests model inference)
('T-1020',
 'The thing is broken again. Same as last week. Please fix ASAP. — Pete',
 NOW() - INTERVAL '2 minutes');

-- -----------------------------------------------------------------------------
-- Verify
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*)                                          AS total_tickets,
    SUM(CASE WHEN processed = 0 THEN 1 ELSE 0 END)   AS pending,
    SUM(CASE WHEN processed = 1 THEN 1 ELSE 0 END)   AS processed
FROM helpdesk.tickets;