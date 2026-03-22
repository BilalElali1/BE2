# Troubleshooting Guide

Common issues, diagnostics, and fixes for the M365 M&A Discovery solution.

---

## Table of Contents

1. [Authentication Failures](#1-authentication-failures)
2. [API Permission Errors](#2-api-permission-errors)
3. [Certificate Issues](#3-certificate-issues)
4. [File Locking](#4-file-locking)
5. [Rate Limiting](#5-rate-limiting)
6. [Excel Template Preservation](#6-excel-template-preservation)
7. [Data Quality Issues](#7-data-quality-issues)
8. [Performance Issues](#8-performance-issues)
9. [Diagnostic Commands](#9-diagnostic-commands)

---

## 1. Authentication Failures

### Error: `401 Unauthorized`

**Symptom:**
```
Invoke-RestMethod: {"error":{"code":"InvalidAuthenticationToken","message":"Access token is empty."}}
```

**Causes and Fixes:**

| Cause | Fix |
|---|---|
| Wrong `TenantId` in `config.json` | Open Azure Portal → Microsoft Entra ID → Overview and copy the correct Tenant ID |
| Wrong `ClientId` in `config.json` | Open App Registration → Overview and copy Application (client) ID |
| Wrong `CertificateThumbprint` | Run `Get-ChildItem Cert:\CurrentUser\My` and copy the correct thumbprint |
| Token expired mid-run | Script should auto-renew; if not, re-run the script |
| Certificate not trusted | Ensure the same certificate is in both Azure and the local store |

**Diagnostic:**
```powershell
# Manually test token retrieval
$config = Get-Content ".\config.json" | ConvertFrom-Json
$cert = Get-Item "Cert:\CurrentUser\My\$($config.CertificateThumbprint)" -ErrorAction Stop

$now = [DateTimeOffset]::UtcNow
$exp = $now.AddHours(1)
$nbf = $now

# Build JWT header and claims manually
$header = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(
    '{"alg":"RS256","typ":"JWT","x5t":"' + [Convert]::ToBase64String($cert.GetCertHash()) + '"}'
))
Write-Host "Certificate subject: $($cert.Subject)"
Write-Host "Certificate expires: $($cert.NotAfter)"
Write-Host "Token endpoint: https://login.microsoftonline.com/$($config.TenantId)/oauth2/v2.0/token"
```

---

### Error: `AADSTS700016 - Application not found`

**Symptom:**
```
{"error":"unauthorized_client","error_description":"AADSTS700016: Application with identifier 'yyyyyyyy-yyyy-...' was not found"}
```

**Fix:**
1. Verify `ClientId` in `config.json` matches the App Registration's **Application (client) ID** — not the Object ID.
2. Verify the app registration is in the correct tenant (matching `TenantId`).
3. The app must not be deleted or disabled.

---

### Error: `AADSTS70011 - Scope invalid`

**Symptom:**
```
AADSTS70011: The provided value for the input parameter 'scope' is not valid.
```

**Fix:** Ensure the scope is `https://graph.microsoft.com/.default` (not `https://graph.microsoft.com/User.Read`).

---

### Error: `AADSTS700027 - Client assertion certificate does not match`

**Symptom:**
```
AADSTS700027: Client assertion contains an invalid signature.
```

**Causes:**
- The certificate in `Cert:\CurrentUser\My\<thumbprint>` does not match the one uploaded to Azure.
- The certificate was re-created but the old thumbprint is still in `config.json`.

**Fix:**
1. Export the current certificate: `Export-Certificate -Cert (Get-Item Cert:\CurrentUser\My\<thumbprint>) -FilePath .\new.cer`
2. Upload `new.cer` to **Certificates & secrets** in the Azure App Registration.
3. Wait 2–5 minutes for Azure to propagate the change.

---

## 2. API Permission Errors

### Error: `403 Forbidden — Authorization_RequestDenied`

**Symptom:**
```
{"error":{"code":"Authorization_RequestDenied","message":"Insufficient privileges to complete the operation."}}
```

**Fix:**
1. Open [Azure Portal](https://portal.azure.com) → **Microsoft Entra ID** → **App registrations** → your app.
2. Click **API permissions**.
3. Verify all required permissions are listed and show ✅ **Granted for [Tenant]**.
4. If any permissions are missing, add them and click **Grant admin consent**.
5. Wait 2–5 minutes for permissions to propagate.

**Required permissions checklist:**
```
✅ User.Read.All                              (Application)
✅ Directory.Read.All                         (Application)
✅ Mail.ReadBasic.All                         (Application)
✅ Sites.Read.All                             (Application)
✅ Team.ReadBasic.All                         (Application)
✅ DeviceManagementManagedDevices.Read.All    (Application)
✅ Application.Read.All                       (Application)
✅ AuditLog.Read.All                          (Application)
✅ Reports.Read.All                           (Application)
```

---

### Error: `403 Forbidden — Forbidden` on Intune endpoint

**Symptom:**
```
GET /deviceManagement/managedDevices → 403 Forbidden
```

**Cause:** Either `DeviceManagementManagedDevices.Read.All` is not granted, or the tenant does not have Intune licensing.

**Fix:**
- If no Intune license: The script automatically falls back to Entra device data (`/devices`). The `DataSource` column in Hardware.csv will show `"Entra"`.
- If Intune is licensed: Grant the `DeviceManagementManagedDevices.Read.All` permission and grant admin consent.

---

### Error: `403` on Reports endpoints

**Symptom:**
```
GET /reports/getOneDriveUsageAccountDetail → 403 Forbidden
```

**Cause:** `Reports.Read.All` not granted, or the tenant has report obfuscation enabled.

**Fix:**
1. Grant `Reports.Read.All` Application permission.
2. If data is obfuscated (shows GUIDs instead of names): A Global Administrator must disable obfuscation:
   - Portal: Microsoft 365 Admin Center → **Settings** → **Org settings** → **Reports** → uncheck "Display concealed user, group, and site names in all reports."
   - Or run:
     ```powershell
     # Via Graph API (requires Global Admin)
     $body = '{"privacyProfile":{"activityBasedTimeoutIntervalInMins":null}}'
     # See MS docs for the correct endpoint
     ```

---

## 3. Certificate Issues

### Certificate Not Found in Local Store

**Symptom:**
```powershell
Get-Item : Cannot find path 'Cert:\CurrentUser\My\AABBCC...' because it does not exist.
```

**Fix — Option A: Re-create the certificate**
```powershell
# Run as the same user account that will run the scripts
$cert = New-SelfSignedCertificate `
    -Subject "CN=M365-MA-Discovery" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -KeyAlgorithm RSA `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears(2)

Write-Host "New thumbprint: $($cert.Thumbprint)"
# Update config.json with new thumbprint
# Export and re-upload to Azure App Registration
```

**Fix — Option B: Import from .pfx file**
```powershell
$pfxPath = "C:\Backup\M365-MA-Discovery.pfx"
$pfxPassword = Read-Host "Enter PFX password" -AsSecureString
Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation "Cert:\CurrentUser\My" -Password $pfxPassword
```

---

### Certificate Expired

**Symptom:**
```
AADSTS700027: Certificate expired.
```

**Fix:**
1. Create a new certificate (see SETUP_AND_EXECUTION.md Step 3.1).
2. Export the public key and upload to Azure App Registration.
3. Update `CertificateThumbprint` in `config.json`.
4. Optionally delete the old certificate from Azure.

---

### Certificate in Wrong Store

The scripts look in `Cert:\CurrentUser\My`. If the certificate was installed for all users, it may be in `Cert:\LocalMachine\My`.

**Diagnostic:**
```powershell
$thumbprint = "AABBCCDDEEFF00112233445566778899AABBCCDD"

# Check both stores
$certUser    = Get-Item "Cert:\CurrentUser\My\$thumbprint"    -ErrorAction SilentlyContinue
$certMachine = Get-Item "Cert:\LocalMachine\My\$thumbprint"   -ErrorAction SilentlyContinue

if ($certUser)    { Write-Host "Found in CurrentUser\My" -ForegroundColor Green }
if ($certMachine) { Write-Host "Found in LocalMachine\My — scripts may need adjustment" -ForegroundColor Yellow }
if (-not $certUser -and -not $certMachine) { Write-Host "Not found in any store" -ForegroundColor Red }
```

**Fix:** Export from `LocalMachine\My` and import into `CurrentUser\My`:
```powershell
# Export from LocalMachine (requires Admin)
$cert = Get-Item "Cert:\LocalMachine\My\$thumbprint"
$exportPath = "$env:TEMP\cert_export.pfx"
$pwd = Read-Host "Set export password" -AsSecureString
Export-PfxCertificate -Cert $cert -FilePath $exportPath -Password $pwd

# Import to CurrentUser
Import-PfxCertificate -FilePath $exportPath -CertStoreLocation "Cert:\CurrentUser\My" -Password $pwd
Remove-Item $exportPath
```

---

## 4. File Locking

### Error: Excel File Locked

**Symptom:**
```
Exception calling "Save" with "0" argument(s): "The process cannot access the file because it is being used by another process."
```

**Fix:**
1. Close `IT M&A Discovery Workbook Template.xlsx` in Excel.
2. Close any output workbooks in `Output/`.
3. Check for lock files (e.g., `~$IT M&A Discovery Workbook Template.xlsx`) and delete them if Excel is not running.

```powershell
# Find and remove Excel lock files
Get-ChildItem "." -Filter "~$*" -Recurse | Remove-Item -Force
```

---

### Error: CSV File Locked

**Symptom:**
```
Cannot access the file 'Output/csv_diagnostics/IdentitySummary.csv' because it is being used by another process.
```

**Fix:**
1. Close any open spreadsheet applications that have a CSV file open.
2. Check if a previous script run is still in progress (check Task Manager for `powershell.exe`).
3. Wait for the previous run to complete before starting a new one.

---

## 5. Rate Limiting

### Error: `429 Too Many Requests`

**Symptom:**
```
Invoke-RestMethod: {"error":{"code":"TooManyRequests","message":"Too many requests, please try again later."}}
```

**How the scripts handle this:**
The scripts include automatic retry logic with exponential back-off:
1. On `429`, read the `Retry-After` header (seconds to wait).
2. If no header, wait 30 seconds and retry.
3. Retry up to 5 times before logging the error and continuing.

**Manual fix if scripts still fail:**
```powershell
# Check the Retry-After value from the response headers
$response = Invoke-WebRequest -Uri "https://graph.microsoft.com/v1.0/users" `
    -Headers @{ Authorization = "Bearer $token" } -ErrorAction SilentlyContinue

if ($response.StatusCode -eq 429) {
    $retryAfter = $response.Headers["Retry-After"]
    Write-Host "Rate limited. Retry after $retryAfter seconds."
    Start-Sleep -Seconds ([int]$retryAfter + 5)
}
```

**Prevention for large tenants:**
- Run exports during off-peak hours (e.g., nights, weekends).
- The script uses `$top=999` (maximum page size) to minimize the number of API calls.

---

## 6. Excel Template Preservation

### Problem: Template Formatting Lost

**Symptom:** After running `4-PopulateTemplate.ps1`, the Excel file has lost colors, fonts, column widths, or charts.

**Fix:** The `4-PopulateTemplate.ps1` script writes data to cells without touching formatting. If formatting is lost:
1. Check that the script opens the **existing template** file (`IT M&A Discovery Workbook Template.xlsx`), not creating a new one.
2. Verify the script does not call any function that reformats the sheet (e.g., `Format-Excel`, `Set-ExcelColumn`).
3. Restore from a backup of the template if needed.

---

### Problem: Extra Worksheets Added

**Symptom:** The output workbook has extra worksheets not in the original template.

**Fix:** The script should only write to existing worksheets, never add new ones. Check the `4-PopulateTemplate.ps1` logic:
```powershell
# Correct approach — only write if worksheet exists
if ($excelPackage.Workbook.Worksheets[$worksheetName]) {
    # Write data
} else {
    Write-Warning "Worksheet '$worksheetName' not found — skipping"
}
```

---

### Problem: Worksheets Not Populated

**Symptom:** The Excel output file has empty worksheets despite CSV files being present.

**Diagnostic:**
```powershell
# Check that CSV files exist and have data
Get-ChildItem ".\Output\csv_diagnostics\*.csv" | ForEach-Object {
    $rows = (Import-Csv $_.FullName | Measure-Object).Count
    Write-Host "$($_.Name): $rows rows"
}
```

**Common causes:**
| Cause | Fix |
|---|---|
| CSV file name doesn't match worksheet name | Check `DATA-MAPPING.md` for correct file names |
| CSV file is empty (0 rows) | Re-run Step 1 (`1-FullExport-v6.ps1`) |
| Script path incorrect | Ensure scripts are run from the repository root directory |
| Header row mismatch | Verify CSV headers match expected column names in template row 3 |

---

## 7. Data Quality Issues

### Empty or Missing Data in Specific Worksheets

| Worksheet | Common Cause | Fix |
|---|---|---|
| Activity & Licenses — sign-in dates empty | `AuditLog.Read.All` not granted | Grant permission and re-run |
| Hardware — only Entra data | No Intune license or `DeviceManagementManagedDevices.Read.All` not granted | Expected behavior; grant Intune permission if available |
| OneDrive — missing sites | No activity in report period (`D180`) | Check if users have actually used OneDrive |
| SharePoint Subsites — empty | Sites have no subsites | This is normal for modern SharePoint |
| Telephony — phone numbers empty | Users have no phone numbers configured in Microsoft Entra ID | Normal; populate via AD sync or direct entry |

### Duplicate Records

**Cause:** Pagination issue or multiple API calls returning the same record.

**Fix:** The scripts deduplicate by `Id` (object ID) before writing to CSV. If duplicates appear, check the deduplication logic in `1-FullExport-v6.ps1`.

---

## 8. Performance Issues

### Slow Export for Large Tenants

**Expected times for 10,000+ user tenants:**

| Worksheet | Approx. Time |
|---|---|
| Identity Summary | 5–10 min |
| Activity & Licenses | 5–10 min |
| Hardware (Intune) | 10–20 min |
| SharePoint Subsites | 10–30 min (depends on site count) |
| **Total** | **30–90 min** |

**Speed tips:**
- Ensure you are on a fast network connection (scripts run on your local machine).
- Use `$select` to request only needed fields (already implemented in scripts).
- Run during off-peak hours to avoid shared API throttling.
- For very large tenants (50,000+ users), consider running each worksheet export separately.

---

### Out of Memory

**Symptom:**
```
System.OutOfMemoryException: Exception of type 'System.OutOfMemoryException' was thrown.
```

**Fix:**
- Increase the available memory or close other applications.
- Run on a machine with at least 8 GB RAM.
- For very large exports, process in batches using the `-BatchSize` parameter (if implemented).

---

## 9. Diagnostic Commands

### Test Authentication

```powershell
# Quick test: get token and list first user
$config = Get-Content ".\config.json" | ConvertFrom-Json
$cert = Get-Item "Cert:\CurrentUser\My\$($config.CertificateThumbprint)"

# Build client assertion JWT
$now    = [DateTimeOffset]::UtcNow
$jtiVal = [guid]::NewGuid().ToString()

$headerJson  = '{"alg":"RS256","typ":"JWT","x5t":"' +
    [Convert]::ToBase64String($cert.GetCertHash()).TrimEnd('=').Replace('+','-').Replace('/','_') + '"}'
$payloadJson = "{`"aud`":`"https://login.microsoftonline.com/$($config.TenantId)/oauth2/v2.0/token`"," +
    "`"exp`":$($now.AddMinutes(10).ToUnixTimeSeconds())," +
    "`"iss`":`"$($config.ClientId)`"," +
    "`"jti`":`"$jtiVal`"," +
    "`"nbf`":$($now.ToUnixTimeSeconds())," +
    "`"sub`":`"$($config.ClientId)`"}"

$b64Header  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($headerJson)).TrimEnd('=').Replace('+','-').Replace('/','_')
$b64Payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payloadJson)).TrimEnd('=').Replace('+','-').Replace('/','_')

$toSign = "$b64Header.$b64Payload"
$rsa    = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
$sig    = [Convert]::ToBase64String(
    $rsa.SignData([Text.Encoding]::UTF8.GetBytes($toSign),
                  [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                  [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
).TrimEnd('=').Replace('+','-').Replace('/','_')

$jwt = "$toSign.$sig"

$tokenResponse = Invoke-RestMethod `
    -Uri "https://login.microsoftonline.com/$($config.TenantId)/oauth2/v2.0/token" `
    -Method Post `
    -Body @{
        grant_type            = "client_credentials"
        client_id             = $config.ClientId
        client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
        client_assertion      = $jwt
        scope                 = "https://graph.microsoft.com/.default"
    }

if ($tokenResponse.access_token) {
    Write-Host "✅ Authentication successful!" -ForegroundColor Green
    Write-Host "Token expires in: $($tokenResponse.expires_in) seconds"

    # Test a simple Graph call
    $headers = @{ Authorization = "Bearer $($tokenResponse.access_token)" }
    $test = Invoke-RestMethod "https://graph.microsoft.com/v1.0/users?`$top=1&`$select=displayName" -Headers $headers
    Write-Host "✅ Graph API accessible. First user: $($test.value[0].displayName)" -ForegroundColor Green
} else {
    Write-Host "❌ Authentication failed" -ForegroundColor Red
    $tokenResponse
}
```

### List All Certificates in Local Store

```powershell
Get-ChildItem Cert:\CurrentUser\My | Select-Object Thumbprint, Subject, NotAfter |
    Format-Table -AutoSize
```

### Check All Required Graph Permissions

```powershell
# After getting a token, check the app's granted permissions
$config = Get-Content ".\config.json" | ConvertFrom-Json
# (Get token first using the diagnostic above)
$appPerms = Invoke-RestMethod `
    "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$($config.ClientId)'&`$select=appRoles,oauth2PermissionScopes,displayName" `
    -Headers $headers
Write-Host "App found: $($appPerms.value[0].displayName)"
```

### Check Output CSV Row Counts

```powershell
Get-ChildItem ".\Output\csv_diagnostics\*.csv" |
    Sort-Object Name |
    ForEach-Object {
        $rows = @(Import-Csv $_.FullName).Count
        $status = if ($rows -gt 0) { "✅" } else { "⚠️ EMPTY" }
        Write-Host "$status $($_.Name) — $rows rows"
    }
```

### Clear Output and Re-run

```powershell
# WARNING: This deletes all previous CSV output
Remove-Item ".\Output\csv_diagnostics\*.csv" -Force -ErrorAction SilentlyContinue
Write-Host "Output cleared. Ready to re-run exports."
```
