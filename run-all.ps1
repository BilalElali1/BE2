# Run-All.ps1

# Load configuration from config.json
$Config = Get-Content -Raw -Path 'config.json' | ConvertFrom-Json

# Variables
$TenantId = $Config.TenantId
$ClientId = $Config.ClientId
$CertificateThumbprint = $Config.CertificateThumbprint
$OutputDir = "./Output"

# Create Output Directory if it doesn't exist
if (-Not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir
}

# Logging function
Function Log {
    param (
        [string]$Message
    )
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$Timestamp] - $Message"
    Add-Content -Path "$OutputDir/log.txt" -Value "[$Timestamp] - $Message"
}

# Error handling function
Function Handle-Error {
    param (
        [string]$ErrorMessage
    )
    Log "ERROR: $ErrorMessage"
    exit 1
}

# Step 1: FullExport
Function Invoke-FullExport {
    Log "Starting FullExport..."
    .\FullExport-v6.ps1 -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint
    if ($LASTEXITCODE -ne 0) { Handle-Error "FullExport failed!" }
    Log "FullExport completed successfully."
}

# Step 2: GraphReports
Function Invoke-GraphReports {
    Log "Starting GraphReports..."
    .\GraphReports-v9.ps1 -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint
    if ($LASTEXITCODE -ne 0) { Handle-Error "GraphReports failed!" }
    Log "GraphReports completed successfully."
}

# Step 3: MergeLogs
Function Invoke-MergeLogs {
    Log "Starting MergeLogs..."
    .\MergeLogs.ps1 -OutputDir $OutputDir
    if ($LASTEXITCODE -ne 0) { Handle-Error "MergeLogs failed!" }
    Log "MergeLogs completed successfully."
}

# Step 4: PopulateTemplate
Function Invoke-PopulateTemplate {
    Log "Starting PopulateTemplate..."
    .\PopulateTemplate.ps1 -InputDir $OutputDir
    if ($LASTEXITCODE -ne 0) { Handle-Error "PopulateTemplate failed!" }
    Log "PopulateTemplate completed successfully."
}

# Orchestrate the steps
Function Run-All {
    Invoke-FullExport
    Invoke-GraphReports
    Invoke-MergeLogs
    Invoke-PopulateTemplate
    Log "All steps completed successfully!"
}

# Run the orchestration
Run-All
