# CedarLead System Architecture

## 1. Overview

CedarLead is a workflow-driven lead qualification, enrichment, routing, lifecycle management, SLA monitoring, reporting, and regression-testing platform built primarily with n8n.

The system separates business processing, lifecycle management, operational monitoring, error handling, and QA support into independent workflows. This reduces coupling and makes each part easier to test, monitor, and maintain.

The architecture uses:

- n8n for workflow orchestration.

- Docker for local runtime isolation.

- Google Sheets as the lightweight operational data store.

- Gmail for customer, owner, escalation, and management notifications.

- OpenAI as the primary AI enrichment provider.

- Ollama as the local AI fallback provider.

- Postman and Postman CLI for automated API regression testing.

- PowerShell for local regression-test orchestration.

---

## 2. System Context

At a high level, CedarLead receives lead submissions, validates them, prevents duplicates, scores them deterministically, enriches them using AI, assigns lifecycle and SLA metadata, stores them in Google Sheets, and sends the appropriate follow-up notifications.

Additional workflows then manage lifecycle transitions, SLA breaches, operational metrics, management reporting, centralized failures, and QA automation.

```text
External Lead Source
        |
        v
+-------------------------+
| Lead Intake API         |
| POST /lead-intake       |
+------------+------------+
             |
             v
+-------------------------+
| Validation / Dedup      |
+------------+------------+
             |
             v
+-------------------------+
| Deterministic Scoring   |
+------------+------------+
             |
             v
+-------------------------+
| Hybrid AI Enrichment    |
| OpenAI -> Ollama        |
+------------+------------+
             |
             v
+-------------------------+
| Lifecycle + SLA Init    |
+------------+------------+
             |
             v
+-------------------------+
| Google Sheets CRM       |
+------------+------------+
             |
             v
+-------------------------+
| Temperature Routing     |
| HOT / WARM / COLD       |
+------------+------------+
             |
             v
+-------------------------+
| Gmail Notifications     |
+-------------------------+
```

The main system is supported by:

```text
Lead Status API
SLA Monitor
Production Error Handler
QA Support API
Operations Metrics Workflow
Daily Management Report
Postman Regression Suite
```

---

## 3. Workflow Inventory

CedarLead currently contains seven exported n8n workflows.

### 3.1 AI Lead Qualification & Follow-Up Automation

Repository file:

```text
workflows/01-ai-lead-qualification.json
```

Responsibilities:

- Receive incoming leads.

- Validate required fields.

- Normalize submitted values.

- Return a fast HTTP 202 acceptance response.

- Generate a deterministic submission key.

- Block duplicate submissions.

- Calculate deterministic lead score.

- Classify HOT, WARM, or COLD.

- Attempt AI enrichment through OpenAI.

- Fall back to Ollama if OpenAI fails.

- Merge AI enrichment with deterministic lead data.

- Initialize lifecycle and SLA metadata.

- Write or update the lead in Google Sheets.

- Route the lead by temperature.

- Send customer follow-up messages.

- Send HOT-lead owner alerts.

This is the primary business-processing workflow.

---

### 3.2 Lead Status API

Repository file:

```text
workflows/02-lead-status-api.json
```

Endpoint:

```text
POST /webhook/lead-status
```

Responsibilities:

- Authenticate Status API requests.

- Validate lifecycle update requests.

- Find a lead by `leadId`.

- Return HTTP 404 when a lead does not exist.

- Validate lifecycle-state transitions.

- Return HTTP 409 for invalid transitions.

- Support same-state idempotent updates.

- Assign lead owners.

- Update follow-up timestamps.

- Update lifecycle status in Google Sheets.

- Return structured HTTP responses.

Supported lifecycle states:

```text
NEW
CONTACTED
QUALIFIED
PROPOSAL
WON
LOST
```

Allowed transitions:

```text
NEW
  -> CONTACTED
  -> LOST
CONTACTED
  -> QUALIFIED
  -> LOST
QUALIFIED
  -> PROPOSAL
  -> LOST
PROPOSAL
  -> WON
  -> LOST
WON
  -> terminal
LOST
  -> terminal
```

A request that repeats the current lifecycle state is treated idempotently.

---

### 3.3 SLA Monitor & Escalation

Repository file:

```text
workflows/03-sla-monitor-escalation.json
```

Responsibilities:

- Run on a schedule.

- Load all leads from Google Sheets.

- Evaluate active lifecycle records for SLA breaches.

- Determine the effective due date.

- Classify escalation level.

- Send escalation email alerts.

- Record escalation metadata in Google Sheets.

- Enforce cooldown periods to prevent repeated alerts.

SLA policy:

```text
HOT  -> P1 -> 1-hour SLA
WARM -> P2 -> 24-hour SLA
COLD -> P3 -> 72-hour SLA
```

Cooldown policy:

```text
P1 -> 1 hour
P2 -> 6 hours
P3 -> 24 hours
```

Escalation progression:

```text
First escalation  -> LEVEL_1
Second escalation -> LEVEL_2
Third or later    -> LEVEL_3
```

Active states:

```text
NEW
CONTACTED
QUALIFIED
PROPOSAL
```

Terminal states are excluded from SLA escalation:

```text
WON
LOST
```

For `NEW` leads, SLA evaluation uses `slaDueAt`.

For:

```text
CONTACTED
QUALIFIED
PROPOSAL
```

the workflow evaluates `nextFollowUpAt`.

---

### 3.4 Production Error Handler

Repository file:

```text
workflows/04-production-error-handler.json
```

Responsibilities:

- Receive production workflow failures.

- Normalize error details.

- Identify the failed workflow and node.

- Generate a system-failure alert.

- Send the failure notification through Gmail.

Architecture:

```text
Workflow Failure
      |
      v
+------------------------+
| Catch Workflow Failure |
+-----------+------------+
            |
            v
+------------------------+
| Normalize Error        |
+-----------+------------+
            |
            v
+------------------------+
| Send Failure Alert     |
+------------------------+
```

The Error Handler does not assign itself as its own Error Workflow. This avoids recursive failure loops.

---

### 3.5 QA Support API

Repository file:

```text
workflows/05-qa-support-api.json
```

Endpoint:

```text
POST /webhook/qa-lead-lookup
```

Responsibilities:

- Authenticate using a dedicated QA API key.

- Validate a QA lookup email address.

- Poll Google Sheets for an asynchronously created QA lead.

- Return the generated `leadId`.

- Return HTTP 422 for invalid lookup requests.

- Return HTTP 404 when the lead does not appear within the bounded polling window.

- Return HTTP 200 when the lead is found.

The workflow uses bounded polling instead of infinite looping.

Lookup behavior:

```text
Attempt 1 -> immediate
Attempt 2 -> wait 5 seconds
Attempt 3 -> wait 5 seconds
...
Attempt 8 -> wait 5 seconds
```

Successful response example:

```json
{
  "success": true,
  "status": "found",
  "leadId": "CL-20261101-332",
  "email": "cedarlead.qa.example@example.com",
  "lifecycleStatus": "NEW"
}
```

The QA Support API exists to support automated regression testing and is not intended as a normal public business endpoint.

---

### 3.6 Operations Metrics & Reporting

Repository file:

```text
workflows/06-operations-metrics-reporting.json
```

Responsibilities:

- Run automatically every hour.

- Load all leads.

- Compute current operational KPIs.

- Generate a unique metrics snapshot.

- Store the snapshot in the `Metrics` sheet.

- Use idempotent upsert behavior keyed by `snapshotId`.

- Provide historical data for the management dashboard.

Example metrics:

```text
totalLeads
hotLeads
warmLeads
coldLeads
hotPct
warmPct
coldPct
newLeads
contactedLeads
qualifiedLeads
proposalLeads
wonLeads
lostLeads
activeLeads
avgLeadScore
aiSuccessCount
aiFailureCount
openaiCount
ollamaCount
aiFallbackCount
aiFallbackRatePct
overdueLeads
p1Overdue
p2Overdue
p3Overdue
totalEscalations
```

Schedule:

```text
Every hour at minute 05
Timezone: Africa/Accra
```

---

### 3.7 Daily Management Report

Repository file:

```text
workflows/07-daily-management-report.json
```

Responsibilities:

- Run every morning.

- Load metrics history.

- Select the latest metrics snapshot.

- Calculate system health status.

- Generate an HTML management report.

- Send the report through Gmail.

Schedule:

```text
Every day at 07:30
Timezone: Africa/Accra
```

The report includes:

- Total lead volume.

- HOT, WARM, and COLD distribution.

- Average lead score.

- Lifecycle pipeline.

- Active leads.

- Overdue leads.

- P1, P2, and P3 SLA health.

- Total escalations.

- AI enrichment success and failure.

- OpenAI usage.

- Ollama usage.

- AI fallback rate.

- Overall operational status.

---

## 4. Main Lead Processing Flow

The main workflow follows this logical sequence:

```text
Webhook
  |
  v
Validate & Normalize Lead
  |
  v
Is Lead Valid?
  |
  +-- FALSE --> Prepare Validation Rejection
  |                 |
  |                 v
  |             HTTP 422
  |
  +-- TRUE --> Respond Accepted
                 |
                 v
             HTTP 202
                 |
                 v
          Create Submission Key
                 |
                 v
          Block Duplicates
                 |
                 v
       Deterministic Scoring
                 |
                 v
          AI Enrichment
            /       \\
           /         \\
       OpenAI       Ollama
       Primary      Fallback
           \\         /
            \\       /
             v     v
        Merge Enrichment
                 |
                 v
      Initialize Lifecycle
                 |
                 v
         Google Sheets
                 |
                 v
      Route by Temperature
       /        |        \\
      /         |         \\
    HOT       WARM       COLD
     |          |          |
     v          v          v
 Customer    Customer    Customer
  Email       Email       Email
     |
     v
 Owner Alert
```

---

## 5. Fast API Response Design

The Intake API returns HTTP 202 before the complete asynchronous processing chain finishes.

This design prevents the client from waiting for:

- AI processing.

- Google Sheets writes.

- Gmail delivery.

- Lifecycle initialization.

- Routing logic.

The response contract is:

```json
{
  "success": true,
  "status": "accepted",
  "message": "Your enquiry has been received and is being processed."
}
```

This design also explains why the QA Support API performs bounded polling when attempting to discover a newly generated `leadId`.

---

## 6. Deterministic Scoring Architecture

Lead scoring is deterministic and remains authoritative.

AI enrichment does not decide the lead temperature.

This separation is intentional:

```text
Business Rule Engine
        |
        v
leadScore
        |
        v
leadTemperature
        |
        +----------------------+
        |                      |
        v                      v
Routing Decision        AI Enrichment
Authoritative           Advisory
```

Benefits:

- Predictable behavior.

- Easier testing.

- Reduced AI risk.

- Reproducible routing.

- Clear auditability.

---

## 7. Hybrid AI Architecture

The enrichment layer is designed for graceful degradation.

```text
Lead Data
   |
   v
OpenAI Primary
   |
   +-- Success ----------------------+
   |                                 |
   +-- Failure --> Ollama Fallback   |
                      |              |
                      +--------------+
                             |
                             v
                    Merge AI Enrichment
```

OpenAI failure does not block the core lead-processing workflow.

Ollama is accessible from the n8n Docker container through:

```text
http://host.docker.internal:11434
```

Local fallback model used during testing:

```text
qwen2.5:3b-instruct
```

The AI layer can add:

```text
Lead summary
Business need
Pain points
Automation opportunities
Purchase intent
Urgency assessment
Recommended solution
Sales talking points
Recommended next action
Confidence
Provider metadata
Fallback metadata
```

---

## 8. Google Sheets Data Architecture

The primary workbook contains three major sheets:

```text
Leads
Metrics
Dashboard
```

### Leads

The `Leads` sheet stores:

```text
Original lead data
Deterministic scoring
AI enrichment
Lifecycle metadata
Owner assignment
SLA metadata
Follow-up timestamps
Escalation metadata
```

The `leadId` field is used as the persistent lead identifier.

The lead-writing operation uses idempotent update behavior where appropriate to reduce duplicate records.

---

### Metrics

The `Metrics` sheet stores historical KPI snapshots.

Each snapshot has a unique:

```text
snapshotId
```

The workflow performs an upsert using `snapshotId`, making retry behavior safe.

---

### Dashboard

The Dashboard reads from the Metrics history and displays:

```text
Total Leads
HOT Leads
Active Leads
Average Lead Score
Overdue Leads
AI Success
AI Fallback Rate
Total Escalations
```

Charts include:

```text
Lead Temperature Distribution
Lifecycle Pipeline
Overdue Leads by SLA Priority
AI Provider Usage
CedarLead Operational Trend
```

---

## 9. Security Architecture

CedarLead separates API authentication by responsibility.

```text
Intake API Key
   |
   +--> /lead-intake
Status API Key
   |
   +--> /lead-status
QA API Key
   |
   +--> /qa-lead-lookup
```

All use:

```text
x-api-key
```

as the authentication header.

The keys are intentionally different.

This provides privilege separation.

Example:

```text
Intake key used on /lead-intake
-> allowed
Intake key used on /lead-status
-> HTTP 403
```

API secrets are stored in credential systems and runtime environments rather than source code.

---

## 10. Reliability Architecture

CedarLead uses different reliability policies depending on whether an operation is safely retryable.

### Safe Retries

Google Sheets read and idempotent update operations use:

```text
Retry On Fail: ON
Maximum tries: 3
Wait between tries: 2000 ms
```

Examples:

```text
Find Lead by ID
Update lifecycle row
Load Leads for SLA Check
Record SLA Escalation
Load Leads for Metrics
Write Metrics Snapshot
```

---

### Gmail

Gmail send operations use:

```text
Retry On Fail: OFF
On Error: Stop Workflow
```

Blind retries are avoided because an email may have been accepted even when the acknowledgement was lost, which could create duplicate messages.

---

### OpenAI

OpenAI primary enrichment uses:

```text
Retry On Fail: OFF
On Error: Continue using error output
```

Failure moves immediately to Ollama rather than repeatedly retrying quota, authentication, or provider-level errors.

---

### Ollama

Ollama fallback uses:

```text
Retry On Fail: ON
Maximum tries: 2
Wait between tries: 1500 ms
On Error: Continue using error output
```

This provides a short recovery opportunity without blocking the main deterministic lead pipeline.

---

## 11. Workflow Timeouts

Workflow-level timeouts prevent long-running executions.

Configured examples:

```text
Main Lead Workflow        -> 3 minutes
Lead Status API           -> 1 minute
SLA Monitor               -> 2 minutes
Production Error Handler  -> 1 minute
Operations Metrics        -> 2 minutes
Daily Management Report   -> 2 minutes
QA Support API            -> 2 minutes
```

---

## 12. Docker Runtime Architecture

CedarLead runs n8n using Docker Compose.

Host binding:

```text
127.0.0.1:5690
```

Container n8n port:

```text
5678
```

Mapping:

```text
127.0.0.1:5690 -> 5678
```

Binding to `127.0.0.1` keeps the local development instance from being exposed on all host network interfaces.

Persistent n8n state is stored in a named Docker volume:

```text
/home/node/.n8n
```

This preserves:

- n8n configuration.

- encrypted credentials.

- workflow metadata.

- the instance encryption key.

The local file directory is mounted to:

```text
/files
```

---

## 13. Credential Encryption

The local n8n instance has an encryption key stored in its persistent n8n configuration.

The `.n8n` directory is stored in the persistent Docker volume.

The project does not regenerate or replace that key during normal container recreation.

This avoids making previously encrypted n8n credentials unreadable.

---

## 14. Error Handling Model

CedarLead separates business errors from system failures.

Business errors include:

```text
422 validation rejection
404 lead not found
409 invalid lifecycle transition
403 authentication rejection
```

These are controlled API responses.

System failures include:

```text
Unhandled workflow errors
Provider failures not handled locally
Unexpected Google API failures
Unexpected node execution failures
```

System failures can trigger the centralized Production Error Handler.

---

## 15. QA and Regression Architecture

CedarLead has a dedicated Postman collection divided into:

```text
01 - Intake API
02 - Status API
03 - Security
```

Automated test data includes:

```text
qaRunId
qaEmail
qaMessageTag
qaLeadId
qaContactedFollowUpAt
```

The test flow dynamically creates and reuses data:

```text
Valid Intake
    |
    v
Generate unique qaEmail
    |
    v
Duplicate Test
    |
    v
QA Lead Lookup
    |
    v
Capture qaLeadId
    |
    v
NEW -> CONTACTED
    |
    v
Idempotency Tests
    |
    v
Negative Lifecycle Tests
    |
    v
CONTACTED -> QUALIFIED
    |
    v
Security Tests
```

Latest validated full suite:

```text
Requests:   16
Assertions: 64
Passed:     64
Failed:     0
Errors:     0
```

The same suite has passed through:

```text
Postman Desktop Runner
Postman CLI
PowerShell regression runner
```

---

## 16. Regression Runner

Local automation is provided through:

```text
scripts/run-regression.ps1
```

The script:

1\. Verifies Postman CLI.

2\. Sets the local CedarLead base URL.

3\. Securely prompts for Intake, Status, and QA API keys.

4\. Loads the secrets into process-level environment variables.

5\. Runs the selected Postman collection requests.

6\. Preserves the Postman exit code.

7\. Prints PASS or FAIL.

8\. Clears runtime secrets in a `finally` block.

No CedarLead API credentials are hard-coded in the script.

---

## 17. Observability Architecture

CedarLead observability exists at several levels.

### Workflow Level

n8n execution history provides:

```text
Node success/failure
Execution duration
Input/output inspection
Workflow-level errors
```

### Business Level

Google Sheets records:

```text
Lead score
Temperature
Lifecycle status
Owner
SLA deadline
Follow-up deadline
Escalation count
AI provider
AI fallback status
```

### Management Level

The Metrics and Dashboard sheets expose:

```text
Lead distribution
Pipeline status
SLA health
AI health
Escalation activity
Historical trends
```

### Notification Level

Gmail delivers:

```text
Customer follow-ups
HOT owner alerts
SLA escalations
System failure alerts
Daily management reports
```

---

## 18. Design Decisions

### Deterministic Routing Instead of AI Routing

AI is used for enrichment but not for authoritative lead temperature.

Reason:

```text
Business-critical routing should remain predictable and testable.
```

### Separate API Keys

Intake, Status, and QA APIs use different credentials.

Reason:

```text
Reduce blast radius and enforce privilege separation.
```

### Idempotent Writes

Where retries are enabled, writes use stable identifiers such as:

```text
leadId
snapshotId
```

Reason:

```text
Avoid duplicate rows during retry conditions.
```

### No Blind Email Retries

Reason:

```text
Avoid accidental duplicate customer or management emails.
```

### Dedicated QA Support API

Reason:

```text
Allow asynchronous workflow testing without modifying the production Intake response contract.
```

---

## 19. Current Architecture Status

Current validated capabilities:

```text
Lead Intake                  PASS
Duplicate Protection         PASS
Deterministic Scoring        PASS
Hybrid AI Fallback           PASS
Lifecycle Management         PASS
Lifecycle Idempotency        PASS
SLA Monitoring               PASS
Escalation Cooldown          PASS
Centralized Error Handling   PASS
Operational Metrics          PASS
Management Dashboard         PASS
Daily Management Reporting   PASS
API Authentication           PASS
Privilege Separation         PASS
Automated Regression         PASS
```

Automated regression status:

```text
16 requests
64 assertions
64 passed
0 failed
0 errors
```

---

## 20. Production Evolution

The current repository represents a production-style local implementation.

Further production evolution could include:

```text
Managed database instead of Google Sheets
Hosted n8n deployment
Managed secret storage
TLS termination
Domain-based API endpoints
Role-based access control
Centralized logs
External monitoring
Persistent metrics database
CI/CD using a reachable staging environment
Automated backups
Disaster-recovery procedures
```

The current architecture provides a strong foundation for those extensions.
