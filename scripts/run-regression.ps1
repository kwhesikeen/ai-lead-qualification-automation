$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " CedarLead Automated Regression Suite" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# Check Postman CLI
# ------------------------------------------------------------

try {
    $postmanVersion = postman --version
    Write-Host "Postman CLI detected: $postmanVersion" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Postman CLI was not found." -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------
# Runtime configuration
# ------------------------------------------------------------

$env:CEDARLEAD_BASE_URL = "http://localhost:5690"

function Read-CedarLeadSecret {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )

    $secureValue = Read-Host $Prompt -AsSecureString

    return (
        New-Object System.Net.NetworkCredential("", $secureValue)
    ).Password
}

$env:CEDARLEAD_INTAKE_API_KEY = Read-CedarLeadSecret "Paste intakeApiKey"
$env:CEDARLEAD_STATUS_API_KEY = Read-CedarLeadSecret "Paste statusApiKey"
$env:CEDARLEAD_QA_API_KEY = Read-CedarLeadSecret "Paste qaApiKey"

Write-Host ""
Write-Host "CedarLead runtime secrets loaded." -ForegroundColor Green
Write-Host "Base URL: $env:CEDARLEAD_BASE_URL"
Write-Host ""

try {

    # ============================================================
    # IMPORTANT
    #
    # Replace the line below with the exact generated
    # "postman collection run ..." command from Postman.
    #
    # Do NOT paste the "postman login --with-api-key ..." command.
    # ============================================================

    $postmanCommand = @'
postman collection run 59240278-ecc89e58-53be-4cfd-bd96-52f98d906ae1 -e 59240278-95e7a4a1-72d2-4595-9580-20762e63511a -i 59240278-19314efc-fe8e-48f2-b309-4c4b38864c67 -i 59240278-ba29a7b0-a324-4e17-9b2d-6a8fd4b0727a -i 59240278-77e6cdaf-025d-43fb-9c00-378c61632242 -i 59240278-03e8fe9f-3c96-46e4-bc4a-f153c7ad28c5 -i 59240278-541bb031-27e3-4396-90cb-d601de52c2d6 -i 59240278-a16b1126-6343-44f9-89fe-666be5331e46 -i 59240278-10c0c1e1-3dd6-4423-a049-afbbe31c2169 -i 59240278-068e35b6-9bae-494d-bece-6e30d89f69b8 -i 59240278-21891a5f-ee2c-4088-8cef-f5e84c3efb89 -i 59240278-e73da380-5f8e-4290-979b-1ba2990c0413 -i 59240278-c8c665c6-6bca-4458-aa49-f73959c92b28 -i 59240278-63fe1585-d8ca-4fc0-ab86-335dae330496 -i 59240278-f6aa5a3e-0d8a-46ae-9298-835a92d85037 -i 59240278-06e69e0a-905e-409f-92ff-adfe1a20dc53 -i 59240278-effd9d17-47db-47bb-9bce-fcc67f88f7d2 -i 59240278-3578c728-66c1-45ed-858c-5c8489bfa23b
'@

    if ($postmanCommand -match "PASTE_POSTMAN_COLLECTION_RUN_COMMAND_HERE") {
        throw "The Postman collection run command has not been added to this script yet."
    }

    # Supply CedarLead runtime values without storing secrets
    # in the script or Git repository.

    $postmanCommand += ' --env-var "baseUrl=$env:CEDARLEAD_BASE_URL"'
    $postmanCommand += ' --env-var "intakeApiKey=$env:CEDARLEAD_INTAKE_API_KEY"'
    $postmanCommand += ' --env-var "statusApiKey=$env:CEDARLEAD_STATUS_API_KEY"'
    $postmanCommand += ' --env-var "qaApiKey=$env:CEDARLEAD_QA_API_KEY"'

    Write-Host "Starting CedarLead regression suite..." -ForegroundColor Cyan
    Write-Host ""

    Invoke-Expression $postmanCommand

    $exitCode = $LASTEXITCODE

    Write-Host ""

    if ($exitCode -eq 0) {
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host " CEDARLEAD REGRESSION SUITE PASSED" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
    }
    else {
        Write-Host "=========================================" -ForegroundColor Red
        Write-Host " CEDARLEAD REGRESSION SUITE FAILED" -ForegroundColor Red
        Write-Host " Exit code: $exitCode" -ForegroundColor Red
        Write-Host "=========================================" -ForegroundColor Red
    }

    exit $exitCode
}
finally {

    # ------------------------------------------------------------
    # Always remove runtime secrets
    # ------------------------------------------------------------

    Remove-Item Env:CEDARLEAD_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:CEDARLEAD_INTAKE_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:CEDARLEAD_STATUS_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:CEDARLEAD_QA_API_KEY -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "CedarLead runtime secrets cleared." -ForegroundColor Yellow
}