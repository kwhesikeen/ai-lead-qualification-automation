# CedarLead Operations Runbook

## 1. Purpose

This document describes routine CedarLead operations, monitoring, incident checks, lifecycle administration, SLA monitoring, reporting, testing, credential rotation, and basic recovery procedures.

It is intended for the person responsible for operating and maintaining the CedarLead environment.

The operating principle is:

```text
Observe
  |
  v
Detect
  |
  v
Investigate
  |
  v
Correct
  |
  v
Regression Test
  |
  v
Document
```

---

## 2. Core Operational Components

CedarLead currently operates through seven n8n workflows:

```text
01 - AI Lead Qualification & Follow-Up Automation
02 - Lead Status API
03 - SLA Monitor & Escalation
04 - Production Error Handler
05 - QA Support API
06 - Operations Metrics & Reporting
07 - Daily Management Report
```

The workflows provide:

```text
lead intake
lead scoring
AI enrichment
customer follow-up
lifecycle management
SLA monitoring
escalation
failure notification
operational metrics
management reporting
QA support
```

---

## 3. Daily Operator Checklist

A normal daily review should include:

```text
1. Confirm n8n is running.
2. Review failed n8n executions.
3. Check Production Error Handler activity.
4. Review SLA escalation alerts.
5. Review the CedarLead Dashboard.
6. Check overdue lead count.
7. Check AI enrichment health.
8. Confirm latest Metrics snapshot exists.
9. Confirm Daily Management Report was sent.
10. Investigate unusual lead or escalation activity.
```

A full regression run is not required every day unless system changes were made.

---

## 4. Verify Docker Runtime

From the repository root:

```powershell
docker compose ps
```

Expected:

```text
cedarlead-n8n
running
```

The service should expose:

```text
127.0.0.1:5690 -> 5678
```

If the container is not running:

```powershell
docker compose up -d
```

Then:

```powershell
docker compose ps
```

---

## 5. Open n8n

Local URL:

```text
http://localhost:5690
```

Confirm the n8n interface loads successfully.

Do not change the host port unless required.

The CedarLead local environment intentionally uses:

```text
5690
```

rather than host port `5678`.

---

## 6. Workflow Publication State

Scheduled and production webhook workflows must remain published.

Check that production workflows show:

```text
Published
```

Important workflows include:

```text
AI Lead Qualification & Follow-Up Automation 5
CedarLead - Lead Status API
CedarLead - SLA Monitor & Escalation
CedarLead - Production Error Handler
CedarLead - QA Support API
CedarLead - Operations Metrics & Reporting
CedarLead - Daily Management Report
```

An unpublished workflow may prevent:

```text
production webhooks
scheduled executions
automated reports
SLA monitoring
QA lookup
```

from operating as expected.

---

## 7. Intake API Health Check

Endpoint:

```text
POST /webhook/lead-intake
```

A valid request with the correct Intake API key should return:

```text
202 Accepted
```

Typical response:

```json
{
  "success": true,
  "status": "accepted",
  "message": "Your enquiry has been received and is being processed."
}
```

An empty request with the correct credential should return:

```text
422 Unprocessable Entity
```

A request with no credential should return:

```text
403 Forbidden
```

---

## 8. Status API Health Check

Endpoint:

```text
POST /webhook/lead-status
```

Correct authentication combined with invalid data should reach business validation and return:

```text
422 Unprocessable Entity
```

Missing or incorrect authentication should return:

```text
403 Forbidden
```

A valid lifecycle update should normally return:

```text
200 OK
```

---

## 9. Lead Processing Monitoring

A successful fresh lead execution should generally progress through:

```text
Webhook
  |
  v
Validate & Normalize Lead
  |
  v
Is Lead Valid?
  |
  v
Respond Accepted
  |
  v
Create Submission Key
  |
  v
Block Duplicate Submissions
  |
  v
Score Lead Deterministically
  |
  v
AI Enrichment
  |
  v
Merge AI Enrichment
  |
  v
Initialize Lead Lifecycle
  |
  v
Log Lead to Google Sheets
  |
  v
Route by Temperature
  |
  v
Customer / Owner Email
```

If execution stops at:

```text
Block Duplicate Submissions
```

the request may be a previously processed duplicate.

That can be normal behavior.

---

## 10. Duplicate Lead Behavior

The Intake API may still return:

```text
202 Accepted
```

for a duplicate because acknowledgement occurs before downstream duplicate processing.

Expected duplicate execution:

```text
Webhook
  |
  v
Validate
  |
  v
Respond Accepted
  |
  v
Create Submission Key
  |
  v
Block Duplicate Submissions
  |
  v
STOP
```

The duplicate should not continue into:

```text
scoring
AI enrichment
Google Sheets persistence
customer email
owner alert
```

---

## 11. Google Sheets Operational Checks

Primary workbook:

```text
AI Lead Qualification Log
```

Main sheets:

```text
Leads
Metrics
Dashboard
```

### Leads

Check for:

```text
duplicate leadId values
missing lifecycleStatus
unexpected blank SLA fields
unexpected escalationCount increases
failed AI enrichment values
```

### Metrics

Confirm new snapshots are being added periodically.

Each snapshot should have a unique:

```text
snapshotId
```

### Dashboard

Review current operational KPIs and trend charts.

---

## 12. Dashboard Review

Important dashboard KPIs include:

```text
Total Leads
HOT Leads
Active Leads
Average Lead Score
Overdue Leads
AI Success
AI Fallback %
Total Escalations
```

Important charts include:

```text
Lead Temperature Distribution
Lead Lifecycle Pipeline
Overdue Leads by SLA Priority
AI Provider Usage
CedarLead Operational Trend
```

Investigate sudden unexpected changes.

Examples:

```text
large increase in overdue leads
large increase in escalations
AI failure increase
unexpected fall in HOT leads
pipeline stagnation
```

---

## 13. Metrics Schedule

Operations Metrics workflow:

```text
CedarLead - Operations Metrics & Reporting
```

Schedule:

```text
Every hour
At minute 05
Timezone: Africa/Accra
```

Example:

```text
08:05
09:05
10:05
11:05
```

The workflow should create one unique snapshot per execution.

---

## 14. Daily Management Report

Workflow:

```text
CedarLead - Daily Management Report
```

Schedule:

```text
Every day
07:30
Africa/Accra
```

The report should use the most recent Metrics snapshot.

The email includes:

```text
Lead Performance
Lifecycle Pipeline
SLA Health
AI Health
System Status
```

If the report is missing:

```text
1. Check workflow publication.
2. Check workflow execution history.
3. Check Gmail credential.
4. Check Metrics data.
5. Check Production Error Handler.
```

---

## 15. System Status Interpretation

The Daily Management Report calculates an operational status.

Typical status values include:

```text
HEALTHY
ATTENTION REQUIRED
DEGRADED
```

Examples:

```text
overdueLeads > 0
-> ATTENTION REQUIRED
aiFailureCount > 0
-> DEGRADED
```

The status is an operational indicator rather than an n8n execution status.

---

## 16. SLA Monitoring

Workflow:

```text
CedarLead - SLA Monitor & Escalation
```

Active lifecycle states:

```text
NEW
CONTACTED
QUALIFIED
PROPOSAL
```

Terminal states:

```text
WON
LOST
```

SLA priorities:

```text
P1 -> 1-hour SLA
P2 -> 24-hour SLA
P3 -> 72-hour SLA
```

---

## 17. Effective SLA Due Date

For:

```text
NEW
```

CedarLead checks:

```text
slaDueAt
```

For:

```text
CONTACTED
QUALIFIED
PROPOSAL
```

CedarLead checks:

```text
nextFollowUpAt
```

This distinction is important when investigating overdue-lead behavior.

---

## 18. SLA Escalation Cooldown

Current cooldown policy:

```text
P1 -> 1 hour
P2 -> 6 hours
P3 -> 24 hours
```

After an escalation:

```text
lastEscalatedAt
```

and:

```text
escalationCount
```

are updated.

An immediate second SLA run should not generate another escalation while the cooldown is active.

---

## 19. Escalation Levels

Escalation count maps to:

```text
1 -> LEVEL_1
2 -> LEVEL_2
3+ -> LEVEL_3
```

Repeated escalation can be legitimate if:

```text
the lead remains overdue
and
the cooldown period has expired
```

Do not assume an increasing escalation count automatically means a duplicate-alert bug.

---

## 20. Investigating Unexpected Escalations

Check the lead row for:

```text
leadId
lifecycleStatus
priority
slaDueAt
nextFollowUpAt
lastEscalatedAt
escalationCount
```

Then determine:

```text
which timestamp is currently authoritative
whether the lead is actually overdue
whether the cooldown has expired
```

Also inspect the latest SLA Monitor execution.

---

## 21. AI Health Monitoring

Important fields:

```text
aiProvider
aiModel
aiFallbackUsed
aiEnrichmentStatus
aiEnrichmentError
aiConfidence
```

Normal fallback behavior can appear as:

```text
aiProvider = ollama
aiFallbackUsed = true
aiEnrichmentStatus = success
```

This means the primary AI provider did not produce the final enrichment, but the fallback succeeded.

---

## 22. OpenAI Failure

OpenAI is configured as the primary provider.

Policy:

```text
Retry On Fail: OFF
On Error: Continue using error output
```

If OpenAI fails:

```text
OpenAI
  |
  v
Ollama Fallback
```

Do not treat OpenAI failure as a total CedarLead outage if Ollama successfully completes the enrichment.

---

## 23. Ollama Health Check

Host test:

```powershell
ollama run qwen2.5:3b-instruct "Reply with exactly OLLAMA_READY"
```

Expected:

```text
OLLAMA_READY
```

Docker-accessible base URL:

```text
http://host.docker.internal:11434
```

If Ollama fails:

```text
check Ollama service
check model availability
check Docker host connectivity
check n8n credential
```

---

## 24. Gmail Operations

CedarLead uses Gmail for:

```text
customer follow-up
owner alert
SLA escalation
production failure alert
daily management report
```

Gmail nodes intentionally use:

```text
Retry On Fail: OFF
On Error: Stop Workflow
```

Do not enable blind retries without designing an idempotent email-delivery mechanism.

---

## 25. Production Error Handler

Workflow:

```text
CedarLead - Production Error Handler
```

Expected path:

```text
Catch Workflow Failure
  |
  v
Normalize Error Details
  |
  v
Send System Failure Alert
```

If a production workflow fails unexpectedly:

```text
1. Open Production Error Handler executions.
2. Open the corresponding error execution.
3. Identify failed workflow.
4. Identify last failed node.
5. Read normalized error message.
6. Open the original workflow execution.
7. Correct the root cause.
8. Run appropriate regression tests.
```

---

## 26. Error Handler Recursion Protection

The Production Error Handler should use:

```text
Error Workflow:
No Workflow
```

It must not point to itself.

This prevents recursive error handling if the Error Handler itself fails.

---

## 27. Workflow Timeout Monitoring

Configured workflow timeouts include:

```text
Main Lead Workflow        -> 3 minutes
Lead Status API           -> 1 minute
SLA Monitor               -> 2 minutes
Production Error Handler  -> 1 minute
QA Support API            -> 2 minutes
Operations Metrics        -> 2 minutes
Daily Management Report   -> 2 minutes
```

If a workflow repeatedly reaches its timeout:

```text
identify the slow node
inspect external API latency
check Google API performance
check AI-provider performance
review polling behavior
```

Do not simply increase timeouts without understanding the cause.

---

## 28. QA Support API Operations

Endpoint:

```text
POST /webhook/qa-lead-lookup
```

The QA Support API is used by the automated test suite.

Normal behavior:

```text
200 -> lead found
404 -> lead not found before timeout
422 -> invalid lookup
403 -> authentication failure
```

The workflow uses bounded polling.

Do not expose the QA endpoint publicly without appropriate restrictions.

---

## 29. Regression Testing After Changes

Run the full regression suite after changes affecting:

```text
webhooks
authentication
validation
lead scoring
deduplication
lifecycle logic
Google Sheets writes
QA lookup
security
```

From the repository root:

```powershell
.\scripts\run-regression.ps1
```

Expected:

```text
16 requests
64 assertions
64 passed
0 failed
0 errors
```

---

## 30. When Full Regression Is Required

A full regression run should be performed before:

```text
publishing major workflow changes
committing significant logic changes
releasing a new version
changing API authentication
changing lifecycle rules
changing deduplication logic
changing retry policies
changing Google Sheets write behavior
changing QA infrastructure
```

Small documentation-only changes do not require a full API regression run unless they also modify runtime logic.

---

## 31. Git Operational Workflow

Recommended development flow:

```text
main
  |
  +-- feature branch
  |
  +-- documentation branch
  |
  +-- bug-fix branch
```

Before committing:

```powershell
git status
git diff
git diff --check
```

Before pushing:

```powershell
git status
git log -1 --oneline
```

Never commit directly without reviewing the staged diff.

---

## 32. Secret Scan Before Commit

Before security-sensitive commits:

```powershell
git diff --cached
```

Use targeted scans where appropriate.

Never commit:

```text
.env
API keys
Postman API keys
OAuth secrets
passwords
Bearer tokens
private tokens
```

---

## 33. Credential Rotation

If an API credential must be rotated:

```text
1. Generate a replacement key.
2. Update the matching n8n Header Auth credential.
3. Update the matching Postman environment value.
4. Run authentication regression tests.
5. Run the full regression suite.
6. Remove old plaintext copies.
7. Confirm old credential no longer works where appropriate.
```

Credential mapping:

```text
Intake key -> Lead Intake API
Status key -> Lead Status API
QA key     -> QA Support API
```

---

## 34. OpenAI Credential Rotation

If rotating OpenAI credentials:

```text
1. Update n8n OpenAI credential.
2. Test OpenAI node.
3. Verify fallback remains connected.
4. Run a fresh lead.
5. Inspect aiProvider.
6. Run regression suite where appropriate.
```

Do not expose the new key in logs or screenshots.

---

## 35. Google and Gmail Credential Failure

Symptoms can include:

```text
Google Sheets read failure
Google Sheets update failure
Gmail send failure
OAuth authorization failure
```

Actions:

```text
check credential authorization
reconnect credential if required
test one safe node
review Error Handler
run regression tests
```

Do not rebuild unrelated workflow logic before verifying credentials.

---

## 36. Docker Restart Procedure

Safe restart:

```powershell
docker compose down
docker compose up -d
docker compose ps
```

Then verify:

```text
n8n UI
Ollama connectivity
published workflows
credentials
```

Avoid:

```powershell
docker compose down -v
```

unless intentionally deleting persistent n8n data.

---

## 37. Docker Image Updates

The local image is pinned.

Current repository configuration:

```text
n8nio/n8n:2.44.7
```

Before changing the version:

```text
review release notes
backup important n8n state
confirm workflow exports
test in a non-production environment
run complete regression suite
```

Avoid uncontrolled `latest` image upgrades for a stable environment.

---

## 38. Workflow Export Maintenance

After meaningful workflow changes:

```text
1. Publish and regression-test the workflow.
2. Export the latest JSON from n8n.
3. Replace the matching file in workflows/.
4. Run secret scans.
5. Review Git diff.
6. Commit the new export.
```

Workflow mapping:

```text
01-ai-lead-qualification.json
02-lead-status-api.json
03-sla-monitor-escalation.json
04-production-error-handler.json
05-qa-support-api.json
06-operations-metrics-reporting.json
07-daily-management-report.json
```

---

## 39. Operational Data Quality Checks

Periodically check the Leads sheet for:

```text
duplicate leadId
missing email
missing lifecycleStatus
invalid priority
blank SLA due date for active lead
unexpected escalationCount
unexpected AI failure state
```

Also verify lifecycle status values remain within:

```text
NEW
CONTACTED
QUALIFIED
PROPOSAL
WON
LOST
```

---

## 40. Idempotency Monitoring

Important idempotent operations include:

```text
duplicate intake filtering
same-state lifecycle updates
lead row upserts
metrics snapshot upserts
```

Warning signs:

```text
duplicate lead rows
duplicate metrics snapshot rows
follow-up timestamp changes on repeated CONTACTED request
duplicate emails
```

Investigate these immediately.

---

## 41. Metrics Health

The Metrics workflow should periodically create snapshots with:

```text
snapshotId
snapshotAt
```

A missing sequence of snapshots may indicate:

```text
workflow unpublished
schedule disabled
Google Sheets failure
workflow timeout
Production Error Handler event
```

---

## 42. Dashboard Trend Interpretation

A flat trend is not automatically a problem.

For example:

```text
Total Leads 27 -> 27
HOT Leads   17 -> 17
Active Leads 5 -> 5
```

creates horizontal lines.

This correctly indicates no KPI change between snapshots.

---

## 43. Daily Report Verification

A healthy Daily Management Report should contain:

```text
snapshot timestamp
system status
lead performance
lifecycle pipeline
SLA health
AI health
```

If values look stale:

```text
check latest Metrics snapshot
check report execution timestamp
check scheduled Metrics workflow
```

---

## 44. Incident Priority Guidance

Suggested operational categories:

```text
P1 Operational Incident
- Intake API unavailable
- Status API unavailable
- Google Sheets persistence unavailable
- widespread credential failure
P2 Operational Incident
- SLA monitoring failure
- management reporting failure
- Ollama unavailable while OpenAI also fails
- repeated workflow timeouts
P3 Operational Incident
- dashboard formatting issue
- non-critical reporting discrepancy
- documentation issue
```

This operational incident priority model is separate from lead priority P1/P2/P3.

---

## 45. Basic Incident Record

For a significant incident record:

```text
Date/time
Affected workflow
Affected endpoint
Failed node
Observed error
Business impact
Root cause
Corrective action
Regression result
Commit/reference
```

This creates an audit trail for future troubleshooting.

---

## 46. Recommended Maintenance Frequency

Suggested cadence:

```text
Daily
- dashboard review
- Error Handler review
- SLA review
After changes
- regression testing
- workflow export
- Git review
Weekly
- failed execution review
- unusual escalation review
- AI-provider health review
Monthly
- credential review
- dependency/version review
- backup review
- documentation review
```

Adjust the cadence based on production volume and business requirements.

---

## 47. Local Backup Considerations

The persistent n8n state resides in the Docker volume associated with:

```text
/home/node/.n8n
```

Workflow exports in the repository provide a portable representation of workflow logic.

However, workflow exports do not replace:

```text
credential backup strategy
Google Sheets backup
n8n state backup
secret recovery plan
```

A hosted production environment should implement formal backup procedures.

---

## 48. Operator Safety Rules

Do not:

```text
delete Docker volumes casually
commit .env
paste API keys into Git
change encryption keys blindly
enable blind Gmail retries
change lifecycle rules without regression tests
publish untested workflows
expose QA API publicly without controls
```

---

## 49. Normal Healthy State

A normal CedarLead environment should show:

```text
Docker container running
n8n UI reachable
production workflows published
no unexplained failed executions
Metrics snapshots updating
Daily report delivered
SLA workflow executing
Google Sheets accessible
Gmail accessible
Ollama reachable
64-assertion regression suite passing after changes
```

---

## 50. Operations Status

Current validated operating capabilities:

```text
Lead intake                    PASS
Lead qualification             PASS
Duplicate prevention           PASS
Hybrid AI enrichment           PASS
Lifecycle updates              PASS
SLA monitoring                 PASS
SLA cooldown                   PASS
Centralized error handling     PASS
Operational metrics            PASS
Dashboard                      PASS
Daily management reporting     PASS
Automated regression           PASS
Security regression            PASS
```
