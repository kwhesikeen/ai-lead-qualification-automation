$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " CedarLead Automated Regression Suite" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# Repository paths
# ------------------------------------------------------------

$repoRoot = Split-Path -Parent $PSScriptRoot

$collectionPath = Join-Path `
    $repoRoot `
    "postman\CedarLead-API-Regression-Suite.postman_collection.json"

$environmentPath = Join-Path `
    $repoRoot `
    "postman\CedarLead-Local.postman_environment.json"

# ------------------------------------------------------------
# Validate required files
# ------------------------------------------------------------

if (-not (Test-Path -LiteralPath $collectionPath -PathType Leaf)) {
    Write-Host "ERROR: Postman collection file was not found:" -ForegroundColor Red
    Write-Host $collectionPath
    exit 1
}

if (-not (Test-Path -LiteralPath $environmentPath -PathType Leaf)) {
    Write-Host "ERROR: Postman environment template was not found:" -ForegroundColor Red
    Write-Host $environmentPath
    exit 1
}

Write-Host "Collection:" $collectionPath -ForegroundColor DarkGray
Write-Host "Environment:" $environmentPath -ForegroundColor DarkGray
Write-Host ""

# ------------------------------------------------------------
# Validate collection and environment JSON
# ------------------------------------------------------------

try {
    Get-Content -LiteralPath $collectionPath -Raw -Encoding UTF8 |
        ConvertFrom-Json -ErrorAction Stop |
        Out-Null

    Get-Content -LiteralPath $environmentPath -Raw -Encoding UTF8 |
        ConvertFrom-Json -ErrorAction Stop |
        Out-Null

    Write-Host "Postman repository files validated." -ForegroundColor Green
}
catch {
    Write-Host "ERROR: A Postman repository file contains invalid JSON." -ForegroundColor Red
    throw
}

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

$env:CEDARLEAD_INTAKE_API_KEY =
    Read-CedarLeadSecret "Paste intakeApiKey"

$env:CEDARLEAD_STATUS_API_KEY =
    Read-CedarLeadSecret "Paste statusApiKey"

$env:CEDARLEAD_QA_API_KEY =
    Read-CedarLeadSecret "Paste qaApiKey"

Write-Host ""
Write-Host "CedarLead runtime secrets loaded." -ForegroundColor Green
Write-Host "Base URL: $env:CEDARLEAD_BASE_URL"
Write-Host ""

try {
    Write-Host "Starting CedarLead regression suite..." -ForegroundColor Cyan
    Write-Host ""

    & postman collection run `
        $collectionPath `
        -e $environmentPath `
        --env-var "baseUrl=$env:CEDARLEAD_BASE_URL" `
        --env-var "intakeApiKey=$env:CEDARLEAD_INTAKE_API_KEY" `
        --env-var "statusApiKey=$env:CEDARLEAD_STATUS_API_KEY" `
        --env-var "qaApiKey=$env:CEDARLEAD_QA_API_KEY"

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
    Remove-Item Env:CEDARLEAD_BASE_URL `
        -ErrorAction SilentlyContinue

    Remove-Item Env:CEDARLEAD_INTAKE_API_KEY `
        -ErrorAction SilentlyContinue

    Remove-Item Env:CEDARLEAD_STATUS_API_KEY `
        -ErrorAction SilentlyContinue

    Remove-Item Env:CEDARLEAD_QA_API_KEY `
        -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "CedarLead runtime secrets cleared." -ForegroundColor Yellow
}
