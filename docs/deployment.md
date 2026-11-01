# CedarLead Deployment Guide

## 1. Purpose

This document describes how CedarLead should be deployed beyond the current local development environment.

The current repository provides a production-style local architecture, but it is not yet an internet-facing production deployment.

The deployment path is:

```text
Local Development
      |
      v
Staging Environment
      |
      v
Production Environment
      |
      v
Monitoring + Backup + Recovery
```

A hosted CedarLead deployment should preserve the workflow logic already validated locally while replacing development-only infrastructure with production-grade services.

---

## 2. Current Local Deployment

The current CedarLead environment runs:

```text
Windows Host
    |
    +-- Docker Desktop
    |      |
    |      +-- cedarlead-n8n
    |
    +-- Ollama
    +-- Postman
    +-- Google Sheets
    +-- Gmail
```

Local n8n URL:

```text
http://localhost:5690
```

Container port:

```text
5678
```

Host binding:

```text
127.0.0.1:5690
```

This configuration intentionally restricts n8n to the local machine.

---

## 3. Production Deployment Goals

A production deployment should provide:

```text
HTTPS
stable public hostname
persistent n8n storage
secure credential storage
controlled network access
automated restart
backup capability
centralized monitoring
failure alerting
separate staging environment
repeatable deployment
```

The production deployment should not expose development-only interfaces unnecessarily.

---

## 4. Recommended Production Architecture

A production architecture can follow:

```text
Internet
   |
   v
DNS
   |
   v
HTTPS / TLS
   |
   v
Reverse Proxy / Load Balancer
   |
   v
n8n Application
   |
   +-- Managed Database
   |
   +-- Persistent Storage
   |
   +-- Google APIs
   |
   +-- Gmail
   |
   +-- OpenAI
   |
   +-- Optional Ollama Service
```

Public users should communicate with the HTTPS endpoint rather than directly with the n8n container port.

---

## 5. Deployment Environments

Use at least two environments:

```text
STAGING
PRODUCTION
```

Optional:

```text
DEVELOPMENT
STAGING
PRODUCTION
```

Each environment should have separate:

```text
API credentials
webhook URLs
Google Sheets or database resources
n8n credentials
monitoring
environment configuration
```

Production credentials should never be reused in development.

---

## 6. Development Environment

Purpose:

```text
workflow development
manual testing
Postman development
local Ollama testing
documentation
```

Current local endpoint:

```text
http://localhost:5690
```

Development data should not be treated as production business data.

---

## 7. Staging Environment

Staging should closely resemble production.

Use staging for:

```text
workflow import testing
credential verification
API regression
deployment validation
version upgrades
failure testing
new lifecycle logic
new scoring logic
```

Before production release, CedarLead should pass the automated regression suite in staging.

---

## 8. Production Environment

Production should be reserved for live lead processing.

Production changes should be controlled.

Recommended release path:

```text
Development
    |
    v
Git branch
    |
    v
Code / Workflow Review
    |
    v
Staging Deployment
    |
    v
Regression Testing
    |
    v
Production Deployment
    |
    v
Smoke Test
    |
    v
Monitoring
```

---

## 9. Production Host Requirements

A hosted CedarLead system requires a server capable of running Docker or another supported n8n hosting architecture.

Minimum architectural requirements include:

```text
persistent storage
stable network connectivity
DNS support
HTTPS support
backup capability
container restart capability
monitoring capability
```

Resource requirements depend on:

```text
lead volume
AI usage
workflow concurrency
execution retention
Ollama usage
database size
```

---

## 10. Public Domain

Production should use a stable hostname.

Example:

```text
automation.example.com
```

or:

```text
cedarlead.example.com
```

Do not expose production using a temporary IP address when a stable domain can be used.

---

## 11. HTTPS

Public CedarLead APIs must use:

```text
HTTPS
```

not plain:

```text
HTTP
```

HTTPS protects:

```text
API keys
lead information
customer data
lifecycle updates
QA requests
```

in transit.

---

## 12. Reverse Proxy

A reverse proxy or managed ingress should sit in front of n8n.

Conceptually:

```text
Client
  |
  v
HTTPS :443
  |
  v
Reverse Proxy
  |
  v
n8n :5678
```

The n8n application port should not normally be exposed directly to the public internet.

---

## 13. Firewall Policy

Production firewall rules should permit only required traffic.

Typical public exposure:

```text
80  -> optional HTTP redirect
443 -> HTTPS
```

Internal service ports should remain restricted.

Examples:

```text
n8n container port
database port
Ollama port
administrative interfaces
```

should not be publicly accessible unless explicitly required.

---

## 14. Production Docker Deployment

The local repository uses Docker Compose.

Production can also use container orchestration, but persistent data must be protected.

A production container architecture should provide:

```text
automatic restart
persistent volume
health monitoring
log retention
controlled upgrades
```

Avoid ephemeral n8n storage.

---

## 15. Persistent n8n Data

The local environment currently persists:

```text
/home/node/.n8n
```

through:

```text
n8n_data
```

Production must also use persistent storage.

Without persistence, restarting or replacing the container could destroy:

```text
instance configuration
credentials
workflow metadata
execution state
```

---

## 16. Database Strategy

The current CedarLead portfolio environment uses Google Sheets as the operational lead store.

For larger production workloads, consider migrating application records to a managed relational database.

Potential architecture:

```text
CedarLead
   |
   +-- PostgreSQL
   |
   +-- Google Sheets reporting layer
```

Benefits include:

```text
stronger concurrency
transaction support
query performance
data integrity
indexing
backup tooling
larger scale
```

Google Sheets remains suitable for the current portfolio and low-volume architecture.

---

## 17. Credential Management

Production secrets should be stored in secure credential systems.

Examples include:

```text
n8n credential storage
managed cloud secret manager
secure runtime environment variables
```

Do not store production secrets in:

```text
Git
README.md
documentation
workflow notes
screenshots
public issue trackers
```

---

## 18. CedarLead API Credentials

Production should preserve three separate authentication boundaries:

```text
Intake API Key
Status API Key
QA API Key
```

Mapping:

```text
Intake API Key
-> /webhook/lead-intake
Status API Key
-> /webhook/lead-status
QA API Key
-> /webhook/qa-lead-lookup
```

Each key should be generated independently.

---

## 19. QA Endpoint in Production

The QA Support API exists primarily for regression testing.

Recommended production approaches:

```text
Option A
Disable QA endpoint in production.
Option B
Deploy QA endpoint only in staging.
Option C
Restrict QA endpoint by network or additional controls.
```

The preferred architecture is:

```text
Development -> QA enabled
Staging     -> QA enabled
Production  -> QA restricted or disabled
```

---

## 20. Production Workflow Imports

Production workflow files are stored in:

```text
workflows/
```

Current inventory:

```text
01-ai-lead-qualification.json
02-lead-status-api.json
03-sla-monitor-escalation.json
04-production-error-handler.json
05-qa-support-api.json
06-operations-metrics-reporting.json
07-daily-management-report.json
```

Import only reviewed workflow exports.

---

## 21. Credential Rebinding After Import

Workflow exports should not contain secret credential values.

After import, verify every credential reference.

Required integrations include:

```text
Google Sheets
Gmail
OpenAI
Ollama if used
Intake Header Auth
Status Header Auth
QA Header Auth
```

Do not publish workflows until credentials are validated.

---

## 22. Production Webhook URLs

With a production domain such as:

```text
https://cedarlead.example.com
```

the endpoints become:

```text
POST https://cedarlead.example.com/webhook/lead-intake
POST https://cedarlead.example.com/webhook/lead-status
POST https://cedarlead.example.com/webhook/qa-lead-lookup
```

The QA endpoint may be omitted from public production deployment.

---

## 23. Do Not Use Test Webhooks in Production

Production clients must use:

```text
/webhook/
```

not:

```text
/webhook-test/
```

The test endpoint requires an active manual n8n test listener and is unsuitable for production integrations.

---

## 24. Google Sheets Production Configuration

If Google Sheets remains the production data store, create a dedicated production workbook.

Recommended separation:

```text
AI Lead Qualification Log - Development
AI Lead Qualification Log - Staging
AI Lead Qualification Log - Production
```

Do not point development workflows at live production lead data.

---

## 25. Production Leads Sheet

Production should preserve the expected Leads schema.

Important key field:

```text
leadId
```

The lead persistence operation should continue to match on:

```text
leadId
```

to support retry-safe writes.

---

## 26. Production Metrics Sheet

The Metrics workflow uses:

```text
snapshotId
```

for idempotent snapshot persistence.

Production must preserve this behavior.

Duplicate snapshot rows should be treated as an operational defect.

---

## 27. Gmail Production Setup

Use a production-authorized sender account.

Review:

```text
sender identity
reply address
owner alert destination
SLA destination
error alert destination
daily management report destination
```

before publishing.

Avoid using personal test addresses in production.

---

## 28. Gmail Retry Policy

CedarLead currently uses:

```text
Retry On Fail: OFF
On Error: Stop Workflow
```

for Gmail send operations.

This should remain unless a proper message-idempotency system is implemented.

Blind retries can create duplicate emails.

---

## 29. OpenAI Production Setup

If OpenAI is enabled:

```text
store API key securely
apply appropriate usage controls
monitor failures
monitor cost
verify fallback behavior
```

OpenAI remains an enrichment provider.

It does not control deterministic lead scoring.

---

## 30. Ollama Production Strategy

The current local fallback uses:

```text
qwen2.5:3b-instruct
```

through:

```text
http://host.docker.internal:11434
```

That hostname is specific to the local Docker-host relationship.

A hosted production system should use a production-appropriate network endpoint.

Example architecture:

```text
n8n
 |
 v
Private Ollama Service
```

The Ollama service should not be exposed publicly without appropriate controls.

---

## 31. AI Failure Strategy

Production must preserve:

```text
OpenAI Primary
     |
     +-- success -> continue
     |
     +-- failure -> Ollama Fallback
```

If both providers fail:

```text
deterministic scoring
```

should remain available.

AI enrichment failure must not overwrite or invalidate the authoritative deterministic score.

---

## 32. Production Error Handler

Every applicable production workflow should use:

```text
CedarLead - Production Error Handler
```

The Error Handler itself should use:

```text
Error Workflow:
No Workflow
```

This prevents recursion.

---

## 33. Workflow Timeouts

Current tested timeout configuration:

```text
Main Lead Workflow        -> 3 minutes
Lead Status API           -> 1 minute
SLA Monitor               -> 2 minutes
Production Error Handler  -> 1 minute
QA Support API            -> 2 minutes
Operations Metrics        -> 2 minutes
Daily Management Report   -> 2 minutes
```

Revalidate timeouts under production latency before changing them.

---

## 34. Scheduled Workflows

Production schedules include:

```text
Operations Metrics
-> hourly at minute 05
Daily Management Report
-> daily at 07:30
```

Timezone:

```text
Africa/Accra
```

SLA monitoring also depends on its configured schedule.

Verify timezone before production activation.

---

## 35. Production Monitoring

Monitor:

```text
workflow failures
webhook availability
execution latency
Google Sheets errors
Gmail failures
OpenAI failures
Ollama failures
overdue leads
SLA escalations
AI fallback rate
daily report delivery
metrics freshness
```

Monitoring should distinguish:

```text
business validation errors
from
system failures
```

---

## 36. Health Indicators

Important CedarLead health indicators include:

```text
Intake API response
Status API response
workflow failure count
overdue lead count
AI failure count
AI fallback rate
total escalation count
latest Metrics timestamp
Daily Management Report delivery
```

---

## 37. External Uptime Monitoring

For internet-facing production, configure an external monitor against an appropriate health endpoint or controlled API check.

The monitor should detect:

```text
DNS failure
TLS failure
HTTP availability failure
application outage
```

Avoid using a test that creates real leads on every monitoring cycle.

---

## 38. Logging

Production should retain sufficient logs to investigate:

```text
workflow failure
credential failure
external API outage
unexpected latency
duplicate behavior
SLA issues
```

Logs must not expose plaintext secrets.

---

## 39. Backup Strategy

Back up:

```text
n8n persistent state
workflow exports
production database or Google Sheets
configuration
critical operational records
```

Workflow JSON exports alone are not a complete backup.

---

## 40. Workflow Backup

The Git repository provides version-controlled workflow logic.

After approved workflow changes:

```text
export latest workflow
scan for secrets
review diff
commit to Git
push repository
```

This provides workflow version history.

---

## 41. Data Backup

If Google Sheets remains the production data store, periodically create protected backups or exports.

If migrating to a database, configure:

```text
automated backups
retention policy
restore testing
```

A backup that has never been restored in testing should not be considered fully validated.

---

## 42. Disaster Recovery

A basic CedarLead recovery procedure should include:

```text
1\. Provision clean host.
2\. Install deployment dependencies.
3\. Restore n8n persistent data or rebuild instance.
4\. Import workflow exports.
5\. Restore credentials securely.
6\. Restore data store.
7\. Restore DNS and HTTPS.
8\. Publish workflows.
9\. Run smoke tests.
10\. Run full regression suite.
11\. Resume production traffic.
```

Document any environment-specific recovery details separately.

---

## 43. Deployment Regression Gate

Before production release, the CedarLead regression suite must pass.

Current baseline:

```text
16 requests
64 assertions
64 passed
0 failed
0 errors
```

A failed regression should block production deployment until investigated.

---

## 44. Staging Regression

Run:

```powershell
.\\scripts\\run-regression.ps1
```

against the staging environment.

For hosted staging, update:

```text
baseUrl
```

to the staging URL.

Do not use production API keys against staging.

---

## 45. Production Smoke Testing

After deployment, perform a controlled smoke test.

Verify:

```text
HTTPS works
Intake authentication works
invalid Intake request returns 422
Status authentication works
invalid Status request returns 422
Google Sheets or database is reachable
Gmail integration works
Error Handler is configured
scheduled workflows are published
```

Avoid creating unnecessary production test data.

---

## 46. Release Checklist

Before production release confirm:

```text
correct Git commit selected
workflow exports current
secret scans clean
credentials configured
production data target correct
Gmail destinations correct
webhook authentication configured
timeouts configured
retry policies configured
Error Workflow configured
timezone configured
scheduled workflows published
staging regression passed
backup available
rollback plan available
```

---

## 47. Rollback Strategy

A production change should have a rollback path.

Workflow rollback can use:

```text
previous Git workflow export
previous deployment artifact
previous container image
```

Rollback procedure:

```text
1\. Stop or isolate failing change.
2\. Restore previous known-good configuration.
3\. Re-import previous workflow if required.
4\. Rebind credentials.
5\. Publish restored workflow.
6\. Run smoke tests.
7\. Run regression tests.
8\. Monitor.
```

---

## 48. Docker Image Versioning

The validated local image is:

```text
n8nio/n8n:2.44.7
```

Do not use uncontrolled production upgrades.

Before changing n8n versions:

```text
review release notes
backup persistent data
export workflows
test staging
run regression suite
prepare rollback
```

Pin production versions.

---

## 49. Dependency Upgrades

Treat changes to these as controlled deployments:

```text
n8n
Postman CLI
Ollama
AI model
Google integration
Gmail integration
database
reverse proxy
```

A dependency upgrade can affect workflow behavior even when CedarLead workflow logic has not changed.

---

## 50. Security Before Go-Live

Before public production exposure verify:

```text
HTTPS active
TLS certificate valid
API keys rotated from test values
QA endpoint restricted
firewall configured
n8n administration protected
secrets absent from Git
production credentials separated
backups configured
monitoring active
```

---

## 51. Production Data Protection

Lead records may contain:

```text
name
email
company
job title
business requirements
sales notes
```

Access should therefore be limited to authorized users and services.

Do not expose operational sheets or databases publicly.

---

## 52. Least Privilege

Grant integrations only the permissions they require.

Examples:

```text
Google Sheets credential
-> required workbook access
Gmail credential
-> required mail operations
Status API key
-> Status API only
Intake API key
-> Intake API only
QA API key
-> QA endpoint only
```

This preserves CedarLead's privilege-separation design.

---

## 53. Production Credential Rotation

Establish a credential rotation procedure.

Rotation should include:

```text
generate replacement
update service
validate new credential
invalidate old credential
run regression
document rotation
```

Avoid rotating every integration simultaneously unless required.

---

## 54. Production Incident Response

If deployment creates an outage:

```text
identify affected service
stop further harmful changes
review latest deployment
inspect error handler
inspect logs
rollback if necessary
run smoke tests
run regression
monitor recovery
document incident
```

Do not continue making unrelated changes during an active production incident.

---

## 55. Deployment Evidence

For portfolio or operational evidence, retain non-sensitive screenshots showing:

```text
successful workflows
dashboard
successful regression
Docker runtime
management report
architecture
```

Do not include:

```text
API keys
OAuth tokens
credential values
private customer data
```

---

## 56. CI/CD Evolution

The current PowerShell regression runner is designed for local execution.

A future hosted staging environment can support CI/CD:

```text
Git Push
   |
   v
CI Pipeline
   |
   v
Secret Injection
   |
   v
Deploy to Staging
   |
   v
Postman Regression
   |
   v
Approval
   |
   v
Deploy to Production
```

The existing 64-assertion suite provides a foundation for this evolution.

---

## 57. Future Production Improvements

Potential future improvements include:

```text
managed PostgreSQL
queue-based worker architecture
centralized logging
external observability
rate limiting
API gateway
managed secrets
CI/CD
automatic backups
restore testing
container health checks
horizontal scaling
dedicated staging
```

These are production-evolution steps rather than requirements for demonstrating the current CedarLead portfolio system.

---

## 58. Deployment Readiness Status

Current validated foundation:

```text
Dockerized n8n runtime                 PASS
Persistent n8n storage                 PASS
Workflow exports                       PASS
API authentication                     PASS
Credential separation                  PASS
Duplicate protection                   PASS
Deterministic scoring                  PASS
Hybrid AI fallback                     PASS
Lifecycle API                          PASS
SLA monitoring                         PASS
Centralized error handling             PASS
Operational metrics                    PASS
Dashboard                              PASS
Daily management reporting             PASS
Automated regression                   PASS
Git secret hygiene                     PASS
```

Still required for full public production:

```text
Hosted server                          REQUIRED
Public DNS                             REQUIRED
HTTPS/TLS                              REQUIRED
Production firewall                    REQUIRED
Production secret management           REQUIRED
Formal backup strategy                 REQUIRED
External monitoring                    REQUIRED
Staging environment                    RECOMMENDED
Managed database                       RECOMMENDED FOR SCALE
CI/CD                                  RECOMMENDED
```

---

## 59. Deployment Principle

The CedarLead deployment standard is:

```text
Do not deploy what has not been tested.
Do not expose what does not need to be public.
Do not commit what should remain secret.
Do not upgrade without a rollback path.
Do not call a system production-ready without monitoring and recovery.
```

---

## 60. Current Deployment Position

CedarLead currently represents a fully functional, locally validated, production-style automation system with documented security, monitoring, testing, lifecycle management, and operational controls.

The next infrastructure milestone is deployment to a controlled staging environment with HTTPS, secure hosted credentials, persistent production storage, monitoring, and automated regression testing before any public production release.
