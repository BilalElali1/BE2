# Setup and Execution Guide

Complete step-by-step instructions for deploying and running the M365 M&A Discovery solution.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Azure App Registration](#2-azure-app-registration)
3. [Certificate Creation and Configuration](#3-certificate-creation-and-configuration)
4. [config.json Setup](#4-configjson-setup)
5. [Script Execution Steps](#5-script-execution-steps)
6. [Output Validation](#6-output-validation)
7. [Troubleshooting Quick Reference](#7-troubleshooting-quick-reference)

---

## 1. Prerequisites

### What You Need

| Item | Requirement |
|---|---|
| Windows OS | Windows 10/11 or Windows Server 2019/2022 |
| PowerShell | 5.1 (built-in) or PowerShell 7+ |
| Entra ID Role | Global Reader **or** Global Administrator |
| Intune Role | Intune Service Administrator (for Hardware sheet) |
| Internet | Outbound HTTPS (port 443) to Microsoft endpoints |

### What You Do NOT Need

- ❌ `AzureAD` PowerShell module
- ❌ `Az` PowerShell module
- ❌ `ExchangeOnlineManagement` module
- ❌ `MSOnline` module
- ❌ `Microsoft.Graph` SDK
- ❌ Any third-party tools or NuGet packages

All authentication and API calls use **native PowerShell** (`Invoke-RestMethod`, `System.Security.Cryptography.X509Certificates`, etc.).

### Verify PowerShell Version

```powershell
$PSVersionTable.PSVersion
# Minimum: Major = 5, Minor = 1
```

---

## 2. Azure App Registration

### Step 2.1 — Create the App Registration

1. Open the [Azure Portal](https://portal.azure.com) and sign in as a Global Administrator.
2. Navigate to **Microsoft Entra ID** → **App registrations** → **New registration**.
3. Fill in the form:
   - **Name:** `M365-MA-Discovery` (or any name you prefer)
   - **Supported account types:** `Accounts in this organizational directory only (Single tenant)`
   - **Redirect URI:** Leave blank
4. Click **Register**.
5. Copy the **Application (client) ID** and **Directory (tenant) ID** — you will need these for `config.json`.

### Step 2.2 — Grant API Permissions

1. In your new app registration, click **API permissions** → **Add a permission**.
2. Select **Microsoft Graph** → **Application permissions**.
3. Add the following permissions:

| Permission | Type | Purpose |
|---|---|---|
| `User.Read.All` | Application | Users, Identity, Telephony |
| `Directory.Read.All` | Application | Domains, Groups, DLs, Rooms |
| `Mail.ReadBasic.All` | Application | Mailbox inventory |
| `Sites.Read.All` | Application | SharePoint, OneDrive |
| `Team.ReadBasic.All` | Application | MS Teams |
| `DeviceManagementManagedDevices.Read.All` | Application | Intune devices |
| `Application.Read.All` | Application | Entra registered apps |
| `AuditLog.Read.All` | Application | Sign-in activity |
| `Reports.Read.All` | Application | Usage reports |

4. Click **Grant admin consent for [Your Organization]** and confirm.
5. Verify all permissions show a green ✅ **Granted** status.

### Step 2.3 — Record App Details

After registration, note:

```
Tenant ID:    xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Client ID:    yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
```

---

## 3. Certificate Creation and Configuration

### Step 3.1 — Create a Self-Signed Certificate

Open PowerShell **as Administrator** and run:

```powershell
# Create a self-signed certificate valid for 2 years
$cert = New-SelfSignedCertificate `
    -Subject "CN=M365-MA-Discovery" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -KeyAlgorithm RSA `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears(2)

# Display the thumbprint — copy this value
Write-Host "Certificate Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
```

### Step 3.2 — Export the Certificate Public Key

Export the `.cer` file to upload to Azure:

```powershell
# Export certificate (public key only — NO private key)
$certPath = "$env:TEMP\M365-MA-Discovery.cer"
Export-Certificate -Cert $cert -FilePath $certPath -Type CERT

Write-Host "Certificate exported to: $certPath" -ForegroundColor Green
```

### Step 3.3 — Upload Certificate to Azure App Registration

1. In the Azure Portal, open your app registration.
2. Click **Certificates & secrets** → **Certificates** tab → **Upload certificate**.
3. Browse to `$env:TEMP\M365-MA-Discovery.cer` and upload it.
4. Add a description (e.g., `M365-MA-Discovery-Cert`) and click **Add**.
5. The certificate thumbprint should now appear in the list.

### Step 3.4 — Verify Certificate is in Local Store

```powershell
# Replace with your actual thumbprint
$thumbprint = "AABBCCDDEEFF00112233445566778899AABBCCDD"

$cert = Get-Item "Cert:\CurrentUser\My\$thumbprint" -ErrorAction SilentlyContinue
if ($cert) {
    Write-Host "Certificate found: $($cert.Subject)" -ForegroundColor Green
    Write-Host "Expires: $($cert.NotAfter)" -ForegroundColor Yellow
} else {
    Write-Host "Certificate NOT found in Cert:\CurrentUser\My" -ForegroundColor Red
    Write-Host "Re-run Step 3.1 or import the certificate." -ForegroundColor Red
}
```

---

## 4. config.json Setup

The `config.json` file stores all authentication parameters. It is located at the repository root.

### Template

```json
{
  "TenantId": "<YOUR_TENANT_ID>",
  "ClientId": "<YOUR_CLIENT_ID>",
  "CertificateThumbprint": "<YOUR_CERTIFICATE_THUMBPRINT>",
  "Note": "This file contains sensitive information. Keep it secure and do not share it publicly."
}
```

### Example (replace values with your own)

```json
{
  "TenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "ClientId": "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
  "CertificateThumbprint": "AABBCCDDEEFF00112233445566778899AABBCCDD",
  "Note": "This file contains sensitive information. Keep it secure and do not share it publicly."
}
```

### Security Warning

> ⚠️ **Never commit `config.json` to source control.** Add it to `.gitignore` to prevent accidental exposure.

```
# .gitignore
config.json
Output/
*.log
```

---

## 5. Script Execution Steps

Run all scripts from the repository root directory:

```powershell
Set-Location "C:\M365-Discovery"
```

### Step 1 — Full Tenant Data Export (`1-FullExport-v6.ps1`)

Exports all 16 raw data worksheets to CSV files in `Output/csv_diagnostics/`.

**Command:**
```powershell
.\scripts\1-FullExport-v6.ps1 -ConfigPath ".\config.json"
```

**What it exports:**
- Identity Summary, Activity & Licenses, Domains
- User MBX, Shared MBX, M365 Groups, DLs, Rooms
- OneDrive, MS Teams, SharePoint, SharePoint Subsites
- External Sharing, Apps, Hardware, Telephony

**Expected runtime:** 5–30 minutes depending on tenant size.

**Expected output:**
```
[2026-03-22 10:00:01] Starting M365 tenant export...
[2026-03-22 10:00:03] Authenticating with TenantId: xxxxxxxx...
[2026-03-22 10:00:05] Exporting Identity Summary... 1247 records
[2026-03-22 10:01:12] Exporting Activity & Licenses... 1247 records
...
[2026-03-22 10:15:33] Export complete. Output: Output/csv_diagnostics/
```

---

### Step 2 — Graph Usage Reports (`2-GraphReports-v9.ps1`)

Fetches activity and usage reports from the Microsoft Graph Reports API and merges them into the Activity & Licenses CSV.

**Command:**
```powershell
.\scripts\2-GraphReports-v9.ps1 -ConfigPath ".\config.json"
```

**What it exports:**
- OneDrive usage details (storage, file counts, last activity)
- SharePoint activity file counts
- Teams user activity counts
- Office 365 active user detail

**Expected runtime:** 2–5 minutes.

**Expected output:**
```
[2026-03-22 10:16:00] Fetching Graph usage reports...
[2026-03-22 10:16:05] getOneDriveUsageAccountDetail: 850 rows
[2026-03-22 10:16:08] getSharePointActivityFileCounts: 7 rows
[2026-03-22 10:16:10] getTeamsUserActivityCounts: 7 rows
[2026-03-22 10:16:12] Reports merged into Output/csv_diagnostics/ActivityLicenses.csv
```

---

### Step 3 — Populate Excel Template (`4-PopulateTemplate.ps1`)

Reads all CSV files from `Output/csv_diagnostics/` and writes the data into the corresponding worksheets in `IT M&A Discovery Workbook Template.xlsx`.

**Command:**
```powershell
.\4-PopulateTemplate.ps1 -ConfigPath ".\config.json"
```

**What it does:**
- Opens the Excel template preserving all existing formatting, styles, and charts
- Maps each CSV file to the correct worksheet by name
- Writes data starting from row 4 (row 3 contains headers)
- Calculates and populates the HighLevel Summary worksheet
- Preserves all template worksheets not populated by the export

**Expected runtime:** 1–3 minutes.

**Expected output:**
```
[2026-03-22 10:17:00] Opening template: IT M&A Discovery Workbook Template.xlsx
[2026-03-22 10:17:02] Populating Identity Summary... 1247 rows written
[2026-03-22 10:17:04] Populating Activity & Licenses... 1247 rows written
...
[2026-03-22 10:18:45] HighLevel Summary calculated and written
[2026-03-22 10:18:46] Workbook saved: Output/M365_Discovery_2026-03-22.xlsx
```

---

### Full Execution Example

```powershell
# Set execution policy if needed (run as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Navigate to solution directory
Set-Location "C:\M365-Discovery"

# Step 1: Export raw tenant data
Write-Host "=== STEP 1: Full Export ===" -ForegroundColor Cyan
.\scripts\1-FullExport-v6.ps1 -ConfigPath ".\config.json"

# Step 2: Fetch Graph usage reports
Write-Host "=== STEP 2: Graph Reports ===" -ForegroundColor Cyan
.\scripts\2-GraphReports-v9.ps1 -ConfigPath ".\config.json"

# Step 3: Populate Excel workbook
Write-Host "=== STEP 3: Populate Template ===" -ForegroundColor Cyan
.\4-PopulateTemplate.ps1 -ConfigPath ".\config.json"

Write-Host "=== COMPLETE ===" -ForegroundColor Green
Write-Host "Output: Output/M365_Discovery_$(Get-Date -Format 'yyyy-MM-dd').xlsx"
```

---

## 6. Output Validation

### Verify CSV Files Were Created

```powershell
$csvDir = ".\Output\csv_diagnostics"
$expected = @(
    "IdentitySummary.csv", "ActivityLicenses.csv", "Domains.csv",
    "UserMBX.csv", "SharedMBX.csv", "M365Groups.csv", "DLs.csv",
    "Rooms.csv", "OneDrive.csv", "MSTeams.csv", "SharePoint.csv",
    "SharePointSubsites.csv", "ExternalSharing.csv", "Apps.csv",
    "Hardware.csv", "Telephony.csv"
)

foreach ($file in $expected) {
    $path = Join-Path $csvDir $file
    if (Test-Path $path) {
        $rows = (Import-Csv $path | Measure-Object).Count
        Write-Host "✅ $file — $rows rows" -ForegroundColor Green
    } else {
        Write-Host "❌ MISSING: $file" -ForegroundColor Red
    }
}
```

### Verify Excel Workbook Worksheets

```powershell
$xlPath = ".\Output\M365_Discovery_$(Get-Date -Format 'yyyy-MM-dd').xlsx"
$expected = @(
    "Identity Summary", "Activity & Licenses", "Domains",
    "User MBX", "Shared MBX", "M365 Groups", "DLs", "Rooms",
    "OneDrive", "MS Teams", "SharePoint", "SharePoint Subsites",
    "External Sharing", "Apps", "Hardware", "Telephony",
    "HighLevel Summary"
)

# Load workbook using .NET directly (no modules needed)
Add-Type -AssemblyName "DocumentFormat.OpenXml" -ErrorAction SilentlyContinue

foreach ($sheet in $expected) {
    Write-Host "Expected worksheet: $sheet"
}
Write-Host "Open the Excel file and verify all 17 worksheets are present."
```

### Check Log Files

All scripts write timestamped logs to the `Output/` directory:

```powershell
Get-ChildItem ".\Output\*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 3
# Review the latest log for errors
Get-Content ".\Output\export_$(Get-Date -Format 'yyyy-MM-dd').log" | Select-String "ERROR"
```

---

## 7. Troubleshooting Quick Reference

| Symptom | Likely Cause | Fix |
|---|---|---|
| `401 Unauthorized` | Token expired or wrong credentials | Re-check `config.json` values |
| `403 Forbidden` | Missing Graph permissions | Grant admin consent in Azure Portal |
| `Certificate not found` | Cert not in `CurrentUser\My` | Re-run Step 3.1 or import `.pfx` |
| Empty CSV files | API returned no data | Check tenant has data; verify permissions |
| Excel file locked | File open in Excel | Close the file before running Step 3 |
| `Invoke-RestMethod: 429` | Rate limited | Script will auto-retry; or wait and re-run |
| Slow execution | Large tenant (10,000+ users) | Normal — allow up to 60 minutes |
| Missing worksheets | Template path wrong | Ensure `IT M&A Discovery Workbook Template.xlsx` is in repo root |

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
