# run-all.ps1 - Master orchestration script for M365 MA Discovery pipeline

param (
    [string]$ConfigPath = "$PSScriptRoot\config.json"
)

# Resolve config path relative to this script
if (-not [System.IO.Path]::IsPathRooted($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot $ConfigPath
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error "config.json not found at: $ConfigPath"
    Write-Host "Copy config.json.example to config.json and fill in your values."
    exit 1
}

# Load configuration from config.json
try {
    $Config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse config.json: $_"
    Write-Host "Ensure config.json contains valid JSON. See config.json.example for the correct format."
    exit 1
}

# Variables
$TenantId              = $Config.TenantId
$ClientId              = $Config.ClientId
$CertificateThumbprint = $Config.CertificateThumbprint
$OutputDir             = Join-Path $PSScriptRoot "Output"
$LogsDir               = Join-Path $PSScriptRoot "logs"

# Create Output and logs directories if they don't exist
foreach ($dir in @($OutputDir, $LogsDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

$LogFile = Join-Path $LogsDir "run-all.log"

# Logging function
function Write-Log {
    param ([string]$Message)
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line = "[$Timestamp] - $Message"
    Write-Host $Line
    Add-Content -Path $LogFile -Value $Line
}

# Resolve a script path: check $PSScriptRoot\scripts\ first, then $PSScriptRoot\
function Resolve-ScriptPath {
    param ([string]$ScriptName)
    $candidates = @(
        Join-Path $PSScriptRoot "scripts\$ScriptName",
        Join-Path $PSScriptRoot $ScriptName
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

# Step 1: FullExport
function Invoke-FullExport {
    Write-Log "Starting FullExport..."
    $script = Resolve-ScriptPath "1-FullExport-v6.ps1"
    if (-not $script) {
        Write-Log "ERROR: 1-FullExport-v6.ps1 not found. Place it in $PSScriptRoot\scripts\ or $PSScriptRoot\"
        exit 1
    }
    try {
        & $script -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -ErrorAction Stop
    } catch {
        Write-Log "ERROR: FullExport failed! $_"; exit 1
    }
    Write-Log "FullExport completed successfully."
}

# Step 2: GraphReports
function Invoke-GraphReports {
    Write-Log "Starting GraphReports..."
    $script = Resolve-ScriptPath "2-GraphReports-v9.ps1"
    if (-not $script) {
        Write-Log "ERROR: 2-GraphReports-v9.ps1 not found. Place it in $PSScriptRoot\scripts\ or $PSScriptRoot\"
        exit 1
    }
    try {
        & $script -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -ErrorAction Stop
    } catch {
        Write-Log "ERROR: GraphReports failed! $_"; exit 1
    }
    Write-Log "GraphReports completed successfully."
}

# Step 3: MergeLogs
function Invoke-MergeLogs {
    Write-Log "Starting MergeLogs..."
    $script = Resolve-ScriptPath "3-MergeLogs.ps1"
    if (-not $script) {
        Write-Log "ERROR: 3-MergeLogs.ps1 not found. Place it in $PSScriptRoot\scripts\ or $PSScriptRoot\"
        exit 1
    }
    try {
        & $script -OutputDir $OutputDir -ErrorAction Stop
    } catch {
        Write-Log "ERROR: MergeLogs failed! $_"; exit 1
    }
    Write-Log "MergeLogs completed successfully."
}

# Step 4: PopulateTemplate
function Invoke-PopulateTemplate {
    Write-Log "Starting PopulateTemplate..."
    $script = Resolve-ScriptPath "4-PopulateTemplate.ps1"
    if (-not $script) {
        Write-Log "ERROR: 4-PopulateTemplate.ps1 not found. Place it in $PSScriptRoot\scripts\ or $PSScriptRoot\"
        exit 1
    }
    try {
        & $script -InputDir $OutputDir -ErrorAction Stop
    } catch {
        Write-Log "ERROR: PopulateTemplate failed! $_"; exit 1
    }
    Write-Log "PopulateTemplate completed successfully."
}

# Orchestrate all steps
Write-Log "=== M365 MA Discovery Pipeline Starting ==="
Invoke-FullExport
Invoke-GraphReports
Invoke-MergeLogs
Invoke-PopulateTemplate
Write-Log "=== All steps completed successfully! ==="
