# CedarLead Postman Regression Suite

This directory contains the portable Postman assets used to validate the CedarLead APIs.

## Files

- CedarLead-API-Regression-Suite.postman_collection.json
- CedarLead-Local.postman_environment.json

## Running the Regression Suite

From the repository root:

.\scripts\run-regression.ps1

The runner validates the local Postman files, securely prompts for API keys, runs the regression suite, and clears runtime secrets afterward.

## Security

Real API keys are not stored in this repository.

The environment template contains blank values for:

- intakeApiKey
- statusApiKey
- qaApiKey

Never commit populated API keys or exported environments containing live credentials.

## Verified Regression Coverage

The suite currently contains 16 requests and 64 assertions covering:

- valid lead intake
- duplicate handling
- invalid lead validation
- QA lead lookup
- NEW to CONTACTED
- CONTACTED idempotency
- invalid status handling
- lead not found handling
- invalid lifecycle transitions
- CONTACTED to QUALIFIED
- missing API key rejection
- incorrect API key rejection
- endpoint credential isolation

A successful run ends with:

CEDARLEAD REGRESSION SUITE PASSED
