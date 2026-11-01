# CedarLead Security

## 1. Security Overview

CedarLead uses several layers of security controls across API access, local runtime configuration, credential storage, Docker networking, Git hygiene, and automated regression testing.

The main security objectives are:

- Prevent unauthorized access to CedarLead APIs.

- Separate privileges between Intake, Status, and QA functions.

- Keep API credentials out of source control.

- Protect n8n credentials with persistent encryption.

- Limit local Docker exposure.

- Prevent accidental secret leakage through Git.

- Avoid unsafe retry behavior.

- Verify security behavior continuously through automated tests.

---

## 2. API Authentication

CedarLead uses HTTP Header Authentication.

Required header:

```text
x-api-key
```

The system currently uses three separate credentials:

```text
CedarLead API Key - Intake
CedarLead API Key - Status
CedarLead API Key - QA
```

Each credential protects a different API boundary.

---

## 3. Privilege Separation

Credential responsibilities are intentionally separated.

```text
Intake API Key
  -> /webhook/lead-intake
Status API Key
  -> /webhook/lead-status
QA API Key
  -> /webhook/qa-lead-lookup
```

This reduces the blast radius of a compromised credential.

For example:

```text
Intake API Key
  -> Intake API
  -> allowed
Intake API Key
  -> Status API
  -> HTTP 403
```

The automated regression suite explicitly verifies this behavior.

---

## 4. Authentication Failure Behavior

Missing or incorrect API credentials are rejected before CedarLead business logic executes.

Typical response:

```text
403 Forbidden
```

Typical n8n authentication message:

```text
Authorization data is wrong!
```

This prevents invalid credentials from reaching:

```text
lead validation
Google Sheets lookup
lifecycle modification
AI processing
email processing
QA lookup logic
```

---

## 5. Validation After Authentication

Correct credentials do not bypass application validation.

Example:

```text
Correct Intake API Key
        |
        v
Authentication passes
        |
        v
Invalid request body
        |
        v
HTTP 422
```

This demonstrates separation between:

```text
authentication
and
business validation
```

The same principle applies to the Status API.

---

## 6. Credential Storage

CedarLead credentials should be stored only in approved runtime systems.

Examples:

```text
n8n credential store
Postman environment
temporary PowerShell process environment
```

Credentials must not be stored in:

```text
README.md
documentation examples
workflow notes
Git history
docker-compose.yml
committed .env files
screenshots
source code
```

---

## 7. Postman Secret Handling

The local Postman environment contains values such as:

```text
baseUrl
intakeApiKey
statusApiKey
qaApiKey
```

API key values are private runtime values.

The regression collection uses non-secret collection variables such as:

```text
qaRunId
qaEmail
qaMessageTag
qaLeadId
qaContactedFollowUpAt
```

The collection variables are test-state values, not authentication credentials.

---

## 8. PowerShell Regression Secret Handling

The local regression runner is:

```text
scripts/run-regression.ps1
```

The script does not contain hard-coded CedarLead API credentials.

At runtime it securely prompts for:

```text
intakeApiKey
statusApiKey
qaApiKey
```

The secrets are loaded into process-level environment variables:

```text
CEDARLEAD_INTAKE_API_KEY
CEDARLEAD_STATUS_API_KEY
CEDARLEAD_QA_API_KEY
```

The base URL is also injected at runtime.

After the regression run completes, the script clears the runtime environment variables in a `finally` block.

This protects against secrets remaining in the PowerShell process after normal completion or a test failure.

---

## 9. Git Secret Protection

The real local environment file is:

```text
.env
```

It is excluded from Git.

The repository contains only:

```text
.env.example
```

Example:

```env
GENERIC_TIMEZONE=Africa/Accra
```

The repository does not commit real API credentials.

Git verification commands used during hardening included:

```powershell
git check-ignore -v .env
git ls-files .env
```

Expected security state:

```text
.env ignored
.env not tracked
```

---

## 10. Repository Ignore Policy

The repository intentionally excludes local-only files such as:

```text
.env
.vscode/
docker-compose.yml.backup
local runtime files
```

The local runtime directory follows:

```text
local-files/*
!local-files/.gitkeep
```

This preserves the directory structure while preventing runtime content from being committed.

---

## 11. Secret Scanning

Before committing security-sensitive changes, CedarLead uses targeted scans for common credential patterns.

Examples include:

```text
OpenAI-style keys
Google API keys
GitHub personal access tokens
Postman API keys
Bearer tokens
password values
client secrets
```

Workflow JSON exports were scanned before being added to the repository.

The scans returned no detected secret values.

A staged-content scan is also performed before sensitive commits.

---

## 12. n8n Credential Encryption

n8n encrypts stored credentials.

The local CedarLead instance contains an encryption key in its persistent n8n configuration.

The configuration directory is:

```text
/home/node/.n8n
```

This directory is backed by a Docker named volume.

The encryption key is not regenerated during ordinary container recreation.

This is important because changing the encryption key without migration could make previously stored credentials unreadable.

---

## 13. Persistent n8n Storage

Docker mounts:

```text
n8n_data:/home/node/.n8n
```

This preserves important n8n state including:

```text
configuration
workflow metadata
credential metadata
credential encryption information
instance settings
```

A destructive Docker command that removes the named volume can destroy local n8n state.

For that reason, commands that remove Docker volumes should be used only when intentionally rebuilding the instance.

---

## 14. Docker Network Exposure

Local n8n is bound to:

```text
127.0.0.1:5690
```

Container port:

```text
5678
```

Mapping:

```text
127.0.0.1:5690 -> 5678
```

Binding to `127.0.0.1` prevents the local development instance from listening on every network interface.

This is appropriate for local development.

A hosted production deployment should additionally use:

```text
TLS
reverse proxy or ingress
domain-level routing
managed firewall rules
secure secret storage
```

---

## 15. QA Endpoint Isolation

The QA Support API uses its own credential:

```text
CedarLead API Key - QA
```

Endpoint:

```text
POST /webhook/qa-lead-lookup
```

This endpoint exists to support automated regression testing.

It should not be treated as a normal public business endpoint.

For a hosted deployment, recommended options include:

```text
disable QA endpoint in production
restrict QA endpoint by network
protect it with separate staging credentials
run it only in a staging environment
```

---

## 16. Safe Retry Policy

CedarLead does not enable retries blindly.

Retry behavior depends on operation semantics.

### Google Sheets Reads

Safe to retry:

```text
Get Row(s)
Find Lead by ID
Load Leads for SLA Check
Load Leads for Metrics
```

Typical policy:

```text
Retry On Fail: ON
Maximum Tries: 3
Wait Between Tries: 2000 ms
```

---

### Idempotent Google Sheets Updates

Safe retries are used when the same stable identifier targets the same record.

Examples:

```text
leadId
snapshotId
```

This reduces duplicate-write risk.

---

### Gmail

Automatic retries are disabled.

Policy:

```text
Retry On Fail: OFF
On Error: Stop Workflow
```

Reason:

A provider may successfully accept an email while the acknowledgement is lost.

Blindly retrying could send duplicate:

```text
customer emails
owner alerts
SLA alerts
management reports
```

---

### OpenAI

Primary AI enrichment uses:

```text
Retry On Fail: OFF
On Error: Continue using error output
```

Failure proceeds directly to Ollama.

This avoids repeated retries for:

```text
quota errors
authentication errors
provider outages
non-transient API failures
```

---

### Ollama

Fallback policy:

```text
Retry On Fail: ON
Maximum Tries: 2
Wait Between Tries: 1500 ms
On Error: Continue using error output
```

This allows a short recovery window without blocking deterministic lead processing.

---

## 17. Workflow Timeouts

Workflow timeouts reduce the risk of indefinitely hanging executions.

Current configured examples include:

```text
Main Lead Workflow        -> 3 minutes
Lead Status API           -> 1 minute
SLA Monitor               -> 2 minutes
Production Error Handler  -> 1 minute
Operations Metrics        -> 2 minutes
Daily Management Report   -> 2 minutes
QA Support API            -> 2 minutes
```

Timeouts are selected based on the expected responsibilities of each workflow.

---

## 18. Error Handling Security

Business errors are returned as controlled API responses.

Examples:

```text
403 -> authentication failure
404 -> lead not found
409 -> invalid lifecycle transition
422 -> invalid request
```

These are not treated as infrastructure failures.

Unexpected system failures are routed to:

```text
CedarLead - Production Error Handler
```

The Production Error Handler is intentionally configured without itself using another Error Workflow.

This prevents recursive failure loops.

---

## 19. Centralized Failure Alerting

The error-handler architecture is:

```text
Workflow Failure
      |
      v
Catch Workflow Failure
      |
      v
Normalize Error Details
      |
      v
Send System Failure Alert
```

This ensures unexpected workflow failures are visible to operators.

The regression suite previously verified this path using a controlled production failure.

---

## 20. Idempotency as a Security and Reliability Control

Idempotency prevents duplicate side effects when the same request or write operation is repeated.

CedarLead uses several forms of idempotency.

### Duplicate Lead Protection

A deterministic submission key prevents repeated lead-processing actions.

### Lead Persistence

Stable:

```text
leadId
```

values are used for lifecycle updates.

### Metrics Persistence

Stable:

```text
snapshotId
```

values are used for metrics snapshot upserts.

### Lifecycle Updates

Repeated same-state requests preserve existing timestamps where appropriate.

---

## 21. Security Regression Coverage

The Postman security folder verifies:

```text
09 - Intake No API Key
     -> 403
10 - Intake Wrong API Key
     -> 403
11 - Intake Correct API Key
     -> authentication passes
     -> 422 business validation
12 - Status Using Intake Key
     -> 403
13 - Status Correct API Key
     -> authentication passes
     -> 422 business validation
```

This validates both authentication and privilege separation.

---

## 22. Full Regression Validation

Latest full automated suite:

```text
Requests:   16
Assertions: 64
Passed:     64
Failed:     0
Errors:     0
```

The full suite has passed through:

```text
Postman Desktop Runner
Postman CLI
PowerShell regression runner
```

---

## 23. Exported Workflow Security

n8n workflows are exported into:

```text
workflows/
```

Before being prepared for Git, workflow JSON files are scanned for credential-shaped values.

The exported workflow repository should contain:

```text
workflow logic
node configuration
credential references
credential names
```

but not:

```text
actual API keys
OAuth secrets
passwords
private tokens
```

---

## 24. Local Development Threat Model

The current implementation is designed as a secure local development and portfolio environment.

Primary local risks include:

```text
accidental Git secret commit
exposed local API keys
unrestricted Docker network binding
destructive volume removal
unsafe retry behavior
public exposure of QA endpoints
```

Current controls directly address these risks.

---

## 25. Hosted Production Recommendations

For a true internet-facing production deployment, additional controls should be introduced.

Recommended additions:

```text
HTTPS/TLS
managed reverse proxy
managed secrets service
network firewall
IP restrictions where appropriate
rate limiting
centralized logs
external uptime monitoring
regular credential rotation
automated backups
disaster-recovery testing
separate staging and production environments
dedicated production database
role-based access control
```

The current CedarLead repository should be considered a production-style foundation rather than a complete internet-facing security perimeter.

---

## 26. Incident Response Basics

If an API credential is suspected to be exposed:

```text
1\. Rotate the affected credential.
2\. Update the matching n8n credential.
3\. Update the matching Postman/runtime secret.
4\. Retest authentication.
5\. Run the full regression suite.
6\. Review Git history for accidental exposure.
7\. Remove compromised plaintext copies.
```

Separate Intake, Status, and QA credentials allow targeted rotation without replacing every API key.

---

## 27. Security Principles Demonstrated

CedarLead demonstrates:

```text
least privilege
privilege separation
secret hygiene
credential encryption
defense in depth
controlled API validation
idempotency
safe retry design
bounded polling
failure isolation
local network restriction
automated security regression testing
Git secret protection
```

---

## 28. Security Status

Current validated security controls:

```text
.env excluded from Git                  PASS
API credentials separated               PASS
Intake authentication                   PASS
Status authentication                   PASS
QA authentication                       PASS
Privilege separation                    PASS
Credential encryption persistence       PASS
Workflow secret scans                   PASS
Staged secret scans                     PASS
Local-only n8n binding                  PASS
Safe retry policies                     PASS
Workflow timeouts                       PASS
Centralized error handling              PASS
Security regression suite               PASS
```

Latest automated security regression:

```text
0 failed
0 errors
```
