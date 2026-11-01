# CedarLead API Reference

## 1. Overview

CedarLead exposes three authenticated HTTP API endpoints through n8n:

```text
POST /webhook/lead-intake
POST /webhook/lead-status
POST /webhook/qa-lead-lookup
```

Each endpoint uses Header Authentication with:

```text
x-api-key
```

The three APIs use separate credentials:

```text
Lead Intake API  -> Intake API Key
Lead Status API  -> Status API Key
QA Support API   -> QA API Key
```

This separation prevents one credential from automatically granting access to every CedarLead API surface.

---

## 2. Base URL

Local development:

```text
http://localhost:5690
```

Production webhook paths use:

```text
/webhook/
```

n8n test-mode paths use:

```text
/webhook-test/
```

Example local production endpoint:

```text
http://localhost:5690/webhook/lead-intake
```

The `/webhook-test/` form is intended only for manual n8n test-listener sessions.

---

# 3. Authentication

All CedarLead API endpoints use the HTTP header:

```http
x-api-key: <credential>
```

Do not place API credentials in:

```text
URLs
request bodies
Git repositories
README files
workflow notes
screenshots
```

Credentials should remain in:

```text
n8n credentials
Postman environments
secure runtime variables
```

---

# 4. Lead Intake API

## Endpoint

```http
POST /webhook/lead-intake
```

Authentication:

```text
CedarLead Intake API Key
```

Purpose:

- Accept lead submissions.

- Validate required fields.

- Normalize lead data.

- Reject malformed submissions.

- Acknowledge valid submissions quickly.

- Start asynchronous lead qualification and follow-up processing.

---

## 4.1 Request Headers

```http
Content-Type: application/json
x-api-key: <intake-api-key>
```

---

## 4.2 Request Body

Example:

```json
{
  "name": "Michael Owusu",
  "email": "michael@example.com",
  "company": "Nova Process Systems",
  "jobTitle": "Operations Director",
  "companySize": 42,
  "budget": 2200,
  "timeline": "2 weeks",
  "message": "We want to automate lead capture, CRM updates, qualification and customer follow-up."
}
```

Core fields used by validation include:

```text
name
email
message
```

Additional business fields include:

```text
company
jobTitle
companySize
budget
timeline
```

---

## 4.3 Successful Response

HTTP status:

```text
202 Accepted
```

Example:

```json
{
  "success": true,
  "status": "accepted",
  "message": "Your enquiry has been received and is being processed."
}
```

The `202` response means the request was accepted for processing.

It does not mean every downstream asynchronous step has completed.

Downstream processing can include:

```text
duplicate detection
lead scoring
AI enrichment
lifecycle initialization
Google Sheets persistence
routing
customer email
owner alert
```

---

## 4.4 Invalid Lead Response

HTTP status:

```text
422 Unprocessable Entity
```

Example:

```json
{
  "success": false,
  "status": "rejected",
  "message": "The submitted lead data is invalid.",
  "errors": [
    "name is required",
    "email is required",
    "message is required"
  ]
}
```

---

## 4.5 Authentication Failure

Missing or incorrect Intake API key:

```text
403 Forbidden
```

Typical n8n authentication response:

```text
Authorization data is wrong!
```

Authentication failure occurs before CedarLead's business-validation logic runs.

---

## 4.6 Duplicate Submission Behavior

A duplicate submission can still receive:

```text
202 Accepted
```

because the Intake API acknowledges the request before downstream duplicate processing completes.

The internal processing flow then evaluates the submission key:

```text
Create Submission Key
        |
        v
Block Duplicate Submissions
```

If the submission was processed previously, downstream scoring, AI enrichment, persistence, and email actions are skipped.

---

# 5. Lead Status API

## Endpoint

```http
POST /webhook/lead-status
```

Authentication:

```text
CedarLead Status API Key
```

Purpose:

- Update lead lifecycle state.

- Assign a lead owner.

- Update owner email.

- Maintain follow-up timestamps.

- Enforce lifecycle-transition rules.

- Support idempotent same-state requests.

---

## 5.1 Request Headers

```http
Content-Type: application/json
x-api-key: <status-api-key>
```

---

## 5.2 Lifecycle States

Supported values:

```text
NEW
CONTACTED
QUALIFIED
PROPOSAL
WON
LOST
```

Allowed transition map:

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

A request using the same current state is allowed as an idempotent no-change update.

---

## 5.3 NEW to CONTACTED Request

Example:

```json
{
  "leadId": "CL-20261101-332",
  "status": "CONTACTED",
  "assignedOwner": "Sales Owner",
  "assignedOwnerEmail": "owner@example.com"
}
```

Successful response:

```text
200 OK
```

Example:

```json
{
  "success": true,
  "status": "updated",
  "message": "Lead lifecycle status updated successfully.",
  "leadId": "CL-20261101-332",
  "previousStatus": "NEW",
  "lifecycleStatus": "CONTACTED",
  "assignedOwner": "Sales Owner",
  "nextFollowUpAt": "2026-11-02T03:22:13.700Z"
}
```

---

## 5.4 Idempotent CONTACTED Request

If the lead is already:

```text
CONTACTED
```

and another `CONTACTED` request is sent, CedarLead accepts it without creating a new lifecycle event.

Expected:

```text
200 OK
```

Example:

```json
{
  "success": true,
  "status": "updated",
  "leadId": "CL-20261101-332",
  "previousStatus": "CONTACTED",
  "lifecycleStatus": "CONTACTED",
  "assignedOwner": "Sales Owner",
  "nextFollowUpAt": "2026-11-02T03:22:13.700Z"
}
```

The existing follow-up timestamp is preserved.

---

## 5.5 CONTACTED to QUALIFIED

Request:

```json
{
  "leadId": "CL-20261101-332",
  "status": "QUALIFIED"
}
```

Expected response:

```text
200 OK
```

Example:

```json
{
  "success": true,
  "status": "updated",
  "leadId": "CL-20261101-332",
  "previousStatus": "CONTACTED",
  "lifecycleStatus": "QUALIFIED",
  "nextFollowUpAt": "2026-11-02T03:40:48.420Z"
}
```

---

## 5.6 Invalid Status Request

Example:

```json
{
  "status": "CONTACTED"
}
```

The required `leadId` is missing.

Expected:

```text
422 Unprocessable Entity
```

Example:

```json
{
  "success": false,
  "status": "rejected",
  "message": "The status update request is invalid.",
  "errors": [
    "leadId is required"
  ]
}
```

---

## 5.7 Lead Not Found

Example:

```json
{
  "leadId": "CL-20991231-NOTFOUND",
  "status": "CONTACTED"
}
```

Expected:

```text
404 Not Found
```

Example:

```json
{
  "success": false,
  "status": "not_found",
  "message": "No lead was found for the supplied leadId.",
  "leadId": "CL-20991231-NOTFOUND"
}
```

---

## 5.8 Invalid Lifecycle Transition

Example current state:

```text
CONTACTED
```

Request:

```json
{
  "leadId": "CL-20261101-332",
  "status": "WON"
}
```

Expected:

```text
409 Conflict
```

Example:

```json
{
  "success": false,
  "status": "conflict",
  "message": "The requested lifecycle transition is not allowed.",
  "leadId": "CL-20261101-332",
  "currentStatus": "CONTACTED",
  "requestedStatus": "WON",
  "allowedNextStatuses": [
    "QUALIFIED",
    "LOST"
  ]
}
```

---

## 5.9 Status Authentication Failure

Incorrect or missing Status API key:

```text
403 Forbidden
```

An Intake API key used against the Status API is also rejected:

```text
403 Forbidden
```

This verifies privilege separation.

---

# 6. QA Lead Lookup API

## Endpoint

```http
POST /webhook/qa-lead-lookup
```

Authentication:

```text
CedarLead QA API Key
```

Purpose:

- Support automated regression testing.

- Find the QA lead generated by the Intake regression test.

- Return the dynamically generated CedarLead `leadId`.

- Handle asynchronous lead-processing delay through bounded polling.

This endpoint should be treated as QA infrastructure rather than a normal public business endpoint.

---

## 6.1 Request Headers

```http
Content-Type: application/json
x-api-key: <qa-api-key>
```

---

## 6.2 Request Body

Example:

```json
{
  "email": "cedarlead.qa.example@example.com"
}
```

The email must correspond to the dynamically generated QA lead.

---

## 6.3 Successful Lookup

Expected:

```text
200 OK
```

Example:

```json
{
  "success": true,
  "status": "found",
  "leadId": "CL-20261101-332",
  "email": "cedarlead.qa.example@example.com",
  "lifecycleStatus": "NEW"
}
```

The Postman regression suite stores the returned ID as:

```text
qaLeadId
```

for later lifecycle tests.

---

## 6.4 Invalid QA Lookup

Example:

```json
{}
```

Expected:

```text
422 Unprocessable Entity
```

Example:

```json
{
  "success": false,
  "status": "rejected",
  "message": "A valid email is required for QA lead lookup."
}
```

---

## 6.5 QA Lead Not Found

If the QA lead does not appear during the bounded polling window:

```text
404 Not Found
```

Example:

```json
{
  "success": false,
  "status": "not_found",
  "message": "QA lead was not found before the lookup timeout."
}
```

---

## 6.6 Polling Behavior

The QA workflow performs a maximum of eight lookup attempts.

Approximate schedule:

```text
Attempt 1 -> immediate
Attempt 2 -> +5 seconds
Attempt 3 -> +5 seconds
Attempt 4 -> +5 seconds
Attempt 5 -> +5 seconds
Attempt 6 -> +5 seconds
Attempt 7 -> +5 seconds
Attempt 8 -> +5 seconds
```

The workflow terminates after the attempt limit.

This prevents infinite polling.

---

# 7. HTTP Status Code Summary

| Status | Meaning |

|---|---|

| 200 | Successful lifecycle update or QA lookup |

| 202 | Lead accepted for asynchronous processing |

| 403 | Authentication or privilege failure |

| 404 | Requested lead or QA lookup result not found |

| 409 | Invalid lifecycle transition |

| 422 | Request validation failed |

---

# 8. Authentication Matrix

| Endpoint | Intake Key | Status Key | QA Key |

|---|---:|---:|---:|

| `/webhook/lead-intake` | Allowed | Rejected | Rejected |

| `/webhook/lead-status` | Rejected | Allowed | Rejected |

| `/webhook/qa-lead-lookup` | Rejected | Rejected | Allowed |

This separation is intentional.

---

# 9. Postman Environment

Local Postman environment:

```text
CedarLead Local
```

Runtime environment variables include:

```text
baseUrl
intakeApiKey
statusApiKey
qaApiKey
```

Example base URL:

```text
http://localhost:5690
```

Sensitive API key values should remain local/private and should not be committed to source control.

---

# 10. Regression Collection Variables

The regression collection generates and reuses:

```text
qaRunId
qaEmail
qaMessageTag
qaLeadId
qaContactedFollowUpAt
```

Purpose:

```text
qaRunId
-> uniquely identifies a regression run
qaEmail
-> uniquely identifies the generated lead
qaMessageTag
-> prevents reuse of stale test content
qaLeadId
-> stores the CedarLead ID returned by QA lookup
qaContactedFollowUpAt
-> stores the idempotency baseline timestamp
```

---

# 11. Example Automated API Sequence

The full functional sequence is:

```text
01 Valid Intake
        |
        v
02 Duplicate Intake
        |
        v
03 Invalid Intake
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
CONTACTED Baseline
        |
        v
CONTACTED Repeat
        |
        v
Invalid Status Request
        |
        v
Lead Not Found
        |
        v
Invalid Transition
        |
        v
CONTACTED -> QUALIFIED
        |
        v
Security Tests
```

---

# 12. Latest Regression Result

Latest complete automated result:

```text
Requests executed: 16
Requests failed:    0
Assertions executed: 64
Assertions failed:    0
Errors:               0
```

Status:

```text
PASS
```

---

# 13. API Design Notes

## Asynchronous Intake

The Intake API intentionally returns `202` before all downstream processing is complete.

The client should not assume that:

```text
Google Sheets write
AI enrichment
email delivery
lifecycle initialization
```

have completed when the `202` response is received.

---

## Idempotency

Duplicate submission protection and same-state lifecycle updates are intentionally supported.

Where retries are enabled, stable identifiers such as:

```text
leadId
snapshotId
```

are used to reduce duplicate write risk.

---

## QA Isolation

The QA endpoint uses a dedicated credential and is separated from the Intake and Status APIs.

For a hosted production deployment, the QA endpoint should be restricted, disabled, or exposed only within a controlled testing environment.
