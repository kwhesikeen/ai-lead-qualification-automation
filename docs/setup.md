# CedarLead Local Setup Guide

## 1. Overview

This document describes how to set up CedarLead locally on Windows using Docker Desktop, n8n, Google Sheets, Gmail, OpenAI, Ollama, Postman, and Postman CLI.

The local development architecture is:

```text
Windows Host
    |
    +-- Docker Desktop
    |      |
    |      +-- cedarlead-n8n
    |             |
    |             +-- n8n port 5678
    |             +-- exposed locally as 5690
    |
    +-- Ollama
    |      |
    |      +-- port 11434
    |
    +-- Postman
    |
    +-- Google Sheets
    |
    +-- Gmail
```

The local n8n UI is available at:

```text
http://localhost:5690
```

---

## 2. Repository

Repository:

```text
https://github.com/kwhesikeen/ai-lead-qualification-automation.git
```

Clone the repository:

```powershell
git clone https://github.com/kwhesikeen/ai-lead-qualification-automation.git
```

Enter the repository:

```powershell
Set-Location ".\\ai-lead-qualification-automation"
```

Verify:

```powershell
git status
```

Expected:

```text
On branch main
Your branch is up to date with 'origin/main'.
```

---

## 3. Required Software

Install the following before starting:

- Git

- Docker Desktop

- Postman Desktop

- Postman CLI

- Ollama

- A modern browser

- Access to Google Sheets

- Access to Gmail

- Optional OpenAI API access

PowerShell is used for local commands and regression automation.

---

## 4. Environment File

The repository contains:

```text
.env.example
```

Create the local environment file:

```powershell
Copy-Item ".\\.env.example" ".\\.env"
```

The example contains:

```env
GENERIC_TIMEZONE=Africa/Accra
```

The real `.env` file is ignored by Git.

Verify:

```powershell
git check-ignore -v .env
```

The command should report that `.env` is ignored.

Never commit the real `.env`.

---

## 5. Docker Configuration

CedarLead uses:

```text
docker-compose.yml
```

The n8n service is pinned to:

```text
n8nio/n8n:2.44.7
```

The local host mapping is:

```text
127.0.0.1:5690 -> container port 5678
```

This avoids exposing n8n on every host network interface.

The compose file also mounts:

```text
n8n_data:/home/node/.n8n
./local-files:/files
```

The named `n8n_data` volume preserves n8n configuration and credential state.

---

## 6. Start CedarLead n8n

From the repository root:

```powershell
docker compose up -d
```

Check:

```powershell
docker compose ps
```

The n8n container should show an active state.

Expected container name:

```text
cedarlead-n8n
```

Open:

```text
http://localhost:5690
```

---

## 7. Stop and Restart n8n

Stop containers without deleting persistent data:

```powershell
docker compose down
```

Start again:

```powershell
docker compose up -d
```

Do not casually run:

```powershell
docker compose down -v
```

The `-v` option removes Docker volumes and can destroy persistent local n8n state.

---

## 8. Verify Persistent n8n Storage

Run:

```powershell
(docker inspect cedarlead-n8n | ConvertFrom-Json)\[0].Mounts |
    Select-Object Type,Name,Destination
```

Expected persistent destination:

```text
/home/node/.n8n
```

The local CedarLead installation stores n8n configuration and credential-encryption information in this persistent directory.

---

## 9. Ollama Installation

Install Ollama on the Windows host.

Verify:

```powershell
ollama --version
```

Pull the local fallback model:

```powershell
ollama pull qwen2.5:3b-instruct
```

Test:

```powershell
ollama run qwen2.5:3b-instruct "Reply with exactly OLLAMA_READY"
```

Expected:

```text
OLLAMA_READY
```

---

## 10. Ollama Access from Docker

n8n runs inside Docker while Ollama runs on the Windows host.

Use this Ollama base URL inside n8n:

```text
http://host.docker.internal:11434
```

Do not use:

```text
http://localhost:11434
```

inside the n8n container.

From inside the container, `localhost` refers to the container itself.

Optional connectivity test:

```powershell
docker exec cedarlead-n8n node -e "fetch('http://host.docker.internal:11434/api/tags').then(r=>console.log(r.status)).catch(e=>console.error(e.message))"
```

Expected HTTP result:

```text
200
```

---

## 11. Import n8n Workflows

The repository contains seven workflow exports:

```text
workflows/
01-ai-lead-qualification.json
02-lead-status-api.json
03-sla-monitor-escalation.json
04-production-error-handler.json
05-qa-support-api.json
06-operations-metrics-reporting.json
07-daily-management-report.json
```

In n8n, use:

```text
Import from File
```

Import each JSON workflow.

Recommended order:

```text
01-ai-lead-qualification.json
02-lead-status-api.json
03-sla-monitor-escalation.json
04-production-error-handler.json
05-qa-support-api.json
06-operations-metrics-reporting.json
07-daily-management-report.json
```

Imported workflows do not include actual secret credential values.

---

## 12. Required n8n Credentials

Configure the required credentials manually after import.

Required credential categories:

```text
Google Sheets
Gmail
OpenAI
Ollama
Header Auth - Intake
Header Auth - Status
Header Auth - QA
```

Credential display names used during development included:

```text
Google Sheets account
CedarLead API Key - Intake
CedarLead API Key - Status
CedarLead API Key - QA
```

Credential names are not secrets.

---

## 13. Google Sheets Credential

Configure Google Sheets authentication in n8n.

The workflows expect access to the CedarLead workbook.

Workbook used during development:

```text
AI Lead Qualification Log
```

The main sheets are:

```text
Leads
Metrics
Dashboard
```

The Google Sheets nodes in imported workflows must be connected to the correct Google Sheets credential and workbook.

---

## 14. Gmail Credential

Configure Gmail authentication in n8n.

Gmail is used for:

```text
HOT customer email
HOT owner alert
WARM customer email
COLD customer email
SLA escalation alert
production system failure alert
daily management report
```

After importing the workflows, verify that every Gmail node points to the correct Gmail credential.

---

## 15. OpenAI Credential

Configure the OpenAI credential if hosted AI enrichment is required.

The OpenAI node acts as the primary enrichment provider.

If OpenAI fails, CedarLead can fall back to Ollama.

Do not place the OpenAI API key inside workflow JSON, source code, README files, or Git.

---

## 16. Ollama Credential

Configure the Ollama connection in n8n.

Base URL:

```text
http://host.docker.internal:11434
```

Model:

```text
qwen2.5:3b-instruct
```

Test the Ollama model connection before publishing the main Intake workflow.

---

## 17. Intake Header Auth Credential

Create an n8n Header Auth credential.

Name:

```text
CedarLead API Key - Intake
```

Header:

```text
x-api-key
```

Value:

```text
<private intake API key>
```

Assign this credential to the Intake webhook.

Endpoint:

```text
POST /webhook/lead-intake
```

---

## 18. Status Header Auth Credential

Create:

```text
CedarLead API Key - Status
```

Header:

```text
x-api-key
```

Value:

```text
<private status API key>
```

Assign it to:

```text
POST /webhook/lead-status
```

The Status key should be different from the Intake key.

---

## 19. QA Header Auth Credential

Create:

```text
CedarLead API Key - QA
```

Header:

```text
x-api-key
```

Value:

```text
<private QA API key>
```

Assign it to:

```text
POST /webhook/qa-lead-lookup
```

The QA credential should be separate from both Intake and Status credentials.

---

## 20. Generate Local API Keys

A 32-byte random hexadecimal value can be generated in Windows PowerShell:

```powershell
$bytes = New-Object byte\[] 32
$rng = \[System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$key = \[System.BitConverter]::ToString($bytes).Replace("-", "").ToLower()
$key
```

Generate separate keys for:

```text
Intake
Status
QA
```

Do not reuse one key for all three API boundaries.

Do not commit generated values.

---

## 21. Workflow Error Handler

Production workflows should use:

```text
CedarLead - Production Error Handler
```

where appropriate.

Configure this from:

```text
Workflow Settings
-> Error Workflow
```

Do not configure the Production Error Handler to call itself.

Its own Error Workflow should remain:

```text
No Workflow
```

---

## 22. Workflow Timeouts

Verify workflow-level timeout settings after import.

Development configuration:

```text
Main Lead Workflow        -> 3 minutes
Lead Status API           -> 1 minute
SLA Monitor               -> 2 minutes
Production Error Handler  -> 1 minute
QA Support API            -> 2 minutes
Operations Metrics        -> 2 minutes
Daily Management Report   -> 2 minutes
```

Timezone:

```text
Africa/Accra
```

---

## 23. Main Workflow Retry Policy

Verify retry settings after import.

Google Sheets reads and idempotent updates generally use:

```text
Retry On Fail: ON
Max Tries: 3
Wait Between Tries: 2000 ms
```

OpenAI primary:

```text
Retry On Fail: OFF
On Error: Continue using error output
```

Ollama fallback:

```text
Retry On Fail: ON
Max Tries: 2
Wait Between Tries: 1500 ms
On Error: Continue using error output
```

Gmail send nodes:

```text
Retry On Fail: OFF
On Error: Stop Workflow
```

---

## 24. Google Sheets Leads Schema

The `Leads` sheet stores several groups of fields.

Core lead data includes:

```text
receivedAt
name
email
company
jobTitle
companySize
budget
timeline
message
```

Scoring includes:

```text
leadScore
leadTemperature
scoringVersion
scoredAt
```

AI enrichment includes:

```text
aiLeadSummary
aiBusinessNeed
aiPainPoints
aiAutomationOpportunities
aiPurchaseIntent
aiUrgencyAssessment
aiRecommendedSolution
aiSalesTalkingPoints
aiRecommendedNextAction
aiConfidence
aiProvider
aiModel
aiFallbackUsed
aiEnrichmentStatus
aiEnrichmentError
aiEnrichmentVersion
aiPromptVersion
aiEnrichedAt
```

Lifecycle and SLA fields include:

```text
leadId
lifecycleStatus
priority
assignedOwner
assignedOwnerEmail
slaHours
slaDueAt
nextFollowUpAt
lastContactedAt
statusUpdatedAt
lastEscalatedAt
escalationCount
lifecycleVersion
```

---

## 25. Metrics Sheet

The `Metrics` sheet stores operational snapshots.

Important fields include:

```text
snapshotId
snapshotAt
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
metricsVersion
```

---

## 26. Dashboard Sheet

The Dashboard reads from Metrics.

Current dashboard components include:

```text
Total Leads
HOT Leads
Active Leads
Average Lead Score
Overdue Leads
AI Success
AI Fallback Rate
Total Escalations
Lead Temperature Distribution
Lifecycle Pipeline
SLA Priority Health
AI Provider Usage
Operational Trend
```

---

## 27. Postman Environment

Create or configure the Postman environment:

```text
CedarLead Local
```

Variables:

```text
baseUrl
intakeApiKey
statusApiKey
qaApiKey
```

Local value:

```text
baseUrl = http://localhost:5690
```

Use secret/private values for the API keys.

---

## 28. Production Webhook URLs

Local production endpoints:

```text
http://localhost:5690/webhook/lead-intake
http://localhost:5690/webhook/lead-status
http://localhost:5690/webhook/qa-lead-lookup
```

Test webhook URLs use:

```text
/webhook-test/
```

Test URLs require n8n to be actively listening for the test event.

Published workflows use:

```text
/webhook/
```

---

## 29. Publish Workflows

After credentials and settings are verified, publish the workflows.

Recommended verification before publication:

```text
correct credentials
correct workflow timeout
correct timezone
correct Error Workflow
correct Google Sheet
correct Gmail destination
correct webhook authentication
correct retry settings
```

Scheduled workflows must be published before their schedules run automatically.

---

## 30. Verify Intake API

Example Postman request:

```text
POST {{baseUrl}}/webhook/lead-intake
```

Header:

```text
x-api-key: {{intakeApiKey}}
```

Expected valid response:

```text
202 Accepted
```

Invalid body:

```json
{}
```

Expected:

```text
422 Unprocessable Entity
```

---

## 31. Verify Status API

Request:

```text
POST {{baseUrl}}/webhook/lead-status
```

Header:

```text
x-api-key: {{statusApiKey}}
```

A valid lifecycle request should return:

```text
200 OK
```

Incorrect authentication should return:

```text
403 Forbidden
```

---

## 32. Verify QA Support API

Request:

```text
POST {{baseUrl}}/webhook/qa-lead-lookup
```

Header:

```text
x-api-key: {{qaApiKey}}
```

Valid QA lookup:

```json
{
  "email": "<QA lead email>"
}
```

Possible responses:

```text
200 found
404 not found before timeout
422 invalid lookup
403 authentication failure
```

---

## 33. Postman CLI

Verify Postman CLI:

```powershell
postman --version
```

The validated development environment used:

```text
Postman CLI 1.79.0
```

---

## 34. Run the Automated Regression Suite

From the repository root:

```powershell
.\\scripts\\run-regression.ps1
```

The script prompts for:

```text
intakeApiKey
statusApiKey
qaApiKey
```

The values are entered securely and are not displayed.

A successful run should end with:

```text
CEDARLEAD REGRESSION SUITE PASSED
```

Latest validated result:

```text
16 requests
64 assertions
64 passed
0 failed
0 errors
```

---

## 35. Verify Secrets Are Cleared

The regression runner clears runtime secrets automatically.

To confirm manually:

```powershell
if (-not $env:CEDARLEAD_INTAKE_API_KEY) { "Intake secret cleared" }
if (-not $env:CEDARLEAD_STATUS_API_KEY) { "Status secret cleared" }
if (-not $env:CEDARLEAD_QA_API_KEY) { "QA secret cleared" }
```

---

## 36. Common Issue: Port 5678 Cannot Bind

The local CedarLead Docker configuration uses host port:

```text
5690
```

instead of host port `5678`.

If Docker fails to bind a host port, inspect Windows excluded port ranges:

```powershell
netsh interface ipv4 show excludedportrange protocol=tcp
```

Do not change CedarLead networking unnecessarily if `5690` is working.

---

## 37. Common Issue: Test Webhook Not Registered

Error:

```text
The requested webhook "..." is not registered.
```

Cause:

The request used:

```text
/webhook-test/
```

without n8n actively listening.

Fix:

Either click:

```text
Listen for test event
```

or use the published production endpoint:

```text
/webhook/
```

---

## 38. Common Issue: HTTP 403

Typical cause:

```text
missing API key
wrong API key
wrong API key used for endpoint
```

Check:

```text
Intake endpoint -> intakeApiKey
Status endpoint -> statusApiKey
QA endpoint -> qaApiKey
```

---

## 39. Common Issue: Ollama Not Reachable

Confirm Ollama works on Windows:

```powershell
ollama run qwen2.5:3b-instruct "Reply with exactly OLLAMA_READY"
```

Then verify Docker access using:

```text
http://host.docker.internal:11434
```

Do not configure the n8n Ollama credential with container-local `localhost`.

---

## 40. Common Issue: OpenAI Fails

CedarLead is designed to fall back to Ollama.

Expected architecture:

```text
OpenAI Primary
    |
    +-- success -> continue
    |
    +-- failure -> Ollama Fallback
```

The deterministic score remains authoritative even if both AI providers fail.

---

## 41. Common Issue: Duplicate Emails

Do not enable blind retries on Gmail Send nodes.

Current policy:

```text
Retry On Fail: OFF
On Error: Stop Workflow
```

This reduces duplicate-message risk.

---

## 42. Common Issue: Duplicate Google Sheets Rows

Use stable identifiers for retry-safe writes.

Examples:

```text
leadId
snapshotId
```

Lead persistence and Metrics persistence use idempotent matching where appropriate.

---

## 43. Verify Repository Secret Hygiene

Run:

```powershell
git check-ignore -v .env
```

and:

```powershell
git ls-files .env
```

Expected:

```text
.env ignored
.env not tracked
```

Never run `git add .` blindly when secret or local runtime files are present.

---

## 44. Local Setup Completion Checklist

A local CedarLead installation is ready when:

```text
Docker container is running
n8n opens at localhost:5690
Google Sheets credential works
Gmail credential works
OpenAI credential is configured if required
Ollama is reachable from Docker
Intake API key is configured
Status API key is configured
QA API key is configured
all seven workflows are imported
Error Workflow assignments are configured
timeouts are configured
scheduled workflows are published
Postman environment is configured
64-assertion regression suite passes
```

---

## 45. Next Steps After Setup

After successful local setup:

```text
review architecture.md
review api-reference.md
review security.md
review testing.md
review operations.md
review deployment.md
```

For internet-facing deployment, additional controls are required, including TLS, managed secrets, hosted networking, backups, and production monitoring.
