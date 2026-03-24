# M365 M&A Discovery Solution

Automated Microsoft 365 tenant discovery workbook for Mergers & Acquisitions due diligence. Exports 17 worksheets of tenant data directly into the **IT M&A Discovery Workbook Template.xlsx** using only native PowerShell and the Microsoft Graph REST API — no additional modules required.

---

## Solution Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    M365 M&A Discovery Flow                      │
│                                                                 │
│  ┌──────────────┐    ┌────────────────────┐    ┌────────────┐  │
│  │  config.json │───▶│ 1-FullExport-v6.ps1│───▶│ CSV Files  │  │
│  │  TenantId    │    │                    │    │ (17 sheets)│  │
│  │  ClientId    │    │  Microsoft Graph   │    └─────┬──────┘  │
│  │  CertThumb   │    │  REST API calls    │          │         │
│  └──────────────┘    └────────────────────┘          │         │
│                                                      │         │
│  ┌──────────────┐    ┌────────────────────┐          │         │
│  │ modules/     │    │2-GraphReports-v9   │          │         │
│  │ Auth.psm1    │───▶│                    │──────────┘         │
│  │              │    │ Usage/Activity     │                    │
│  └──────────────┘    │ Reports via Graph  │                    │
│                      └────────────────────┘                    │
│                                                                 │
│                      ┌────────────────────┐    ┌────────────┐  │
│                      │ 4-PopulateTemplate │───▶│ Excel      │  │
│                      │    .ps1            │    │ Workbook   │  │
│                      │ Writes CSVs into   │    │ (final)    │  │
│                      │ Excel template     │    └────────────┘  │
│                      └────────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

### Authentication Flow

```
PowerShell Script
      │
      ▼
Certificate (Cert:\CurrentUser\My\<Thumbprint>)
      │
      ▼
POST https://login.microsoftonline.com/<TenantId>/oauth2/v2.0/token
      │  client_credentials grant
      │  client_assertion = JWT signed with certificate
      ▼
Bearer Token (valid 60 min, auto-renewed)
      │
      ▼
Microsoft Graph REST API
https://graph.microsoft.com/v1.0/...
```

---

## System Requirements

| Requirement | Detail |
|---|---|
| Operating System | Windows 10/11 or Windows Server 2019/2022 |
| PowerShell | Version 5.1 or PowerShell 7+ |
| Modules | **None** — native PowerShell only |
| Network | Outbound HTTPS to `login.microsoftonline.com` and `graph.microsoft.com` |
| Certificate | Self-signed or CA-issued, installed in `Cert:\CurrentUser\My` |
| Disk Space | ~500 MB for CSV output files |
| Memory | 4 GB RAM minimum (8 GB recommended for large tenants) |

> **Important:** This solution does **not** use `AzureAD`, `Az`, `ExchangeOnlineManagement`, `MSOnline`, or any other PowerShell modules. All API calls are made directly via `Invoke-RestMethod`.

---

## Registered App Authentication

Authentication uses the **OAuth 2.0 client credentials flow** with a certificate assertion:

1. A self-signed certificate is created and installed in the Windows Certificate Store.
2. The certificate's public key is uploaded to an Azure App Registration.
3. The script loads the certificate from the local store by thumbprint, signs a JWT, and exchanges it for a Bearer token via the Microsoft identity platform.
4. All Graph API calls are made with `Authorization: Bearer <token>` in the header.

**Required Microsoft Graph Application Permissions:**

| Permission | Used For |
|---|---|
| `User.Read.All` | Users, Identity Summary, Activity |
| `Directory.Read.All` | Domains, Groups, DLs, Rooms |
| `Mail.ReadBasic.All` | Mailbox properties |
| `Sites.Read.All` | SharePoint, OneDrive |
| `Team.ReadBasic.All` | MS Teams |
| `DeviceManagementManagedDevices.Read.All` | Hardware (Intune) |
| `Application.Read.All` | Apps registered in Entra |
| `AuditLog.Read.All` | Sign-in activity |
| `Reports.Read.All` | Usage reports |

---

## Quick Start

```powershell
# 1. Clone / download the repository
# 2. Edit config.json with your credentials
# 3. Run the export
cd "C:\M365-Discovery"

# Step 1: Full tenant data export
.\scripts\1-FullExport-v6.ps1 -ConfigPath ".\config.json"

# Step 2: Graph usage reports
.\scripts\2-GraphReports-v9.ps1 -ConfigPath ".\config.json"

# Step 3: Populate the Excel template
.\4-PopulateTemplate.ps1 -ConfigPath ".\config.json"
```

See [SETUP_AND_EXECUTION.md](SETUP_AND_EXECUTION.md) for the full step-by-step guide.

---

## File Structure

```
BE2/
├── README.md                              ← This file
├── SETUP_AND_EXECUTION.md                 ← Step-by-step setup guide
├── DATA-MAPPING.md                        ← CSV-to-worksheet mapping reference
├── TROUBLESHOOTING.md                     ← Common issues and fixes
├── config.json                            ← Authentication configuration (DO NOT COMMIT)
├── IT M&A Discovery Workbook Template.xlsx← Excel output template (17 worksheets)
├── 4-PopulateTemplate.ps1                 ← Script 4: Writes CSVs into Excel template
├── scripts/
│   ├── 1-FullExport-v6.ps1               ← Script 1: Exports all tenant data to CSV
│   └── 2-GraphReports-v9.ps1             ← Script 2: Exports Graph usage reports
└── modules/
    └── Auth.psm1                          ← Shared authentication module
```

### Output Structure (generated at runtime)

```
Output/
└── csv_diagnostics/
    ├── IdentitySummary.csv
    ├── ActivityLicenses.csv
    ├── Domains.csv
    ├── UserMBX.csv
    ├── SharedMBX.csv
    ├── M365Groups.csv
    ├── DLs.csv
    ├── Rooms.csv
    ├── OneDrive.csv
    ├── MSTeams.csv
    ├── SharePoint.csv
    ├── SharePointSubsites.csv
    ├── ExternalSharing.csv
    ├── Apps.csv
    ├── Hardware.csv
    ├── Telephony.csv
    └── HighLevelSummary.csv
```

---

## Worksheets Exported

| # | Worksheet | Graph Endpoint(s) |
|---|---|---|
| 1 | Identity Summary | `/users` |
| 2 | Activity & Licenses | `/users`, `/reports/getOffice365ActiveUserDetail` |
| 3 | Domains | `/domains` |
| 4 | User MBX | `/users?$filter=assignedLicenses/any(...)` |
| 5 | Shared MBX | `/users?$filter=userType eq 'Member'` |
| 6 | M365 Groups | `/groups?$filter=groupTypes/any(c:c eq 'Unified')` |
| 7 | DLs | `/groups?$filter=not groupTypes/any(...)` |
| 8 | Rooms | `/users?$filter=userType eq 'Guest'` (room accounts) |
| 9 | OneDrive | `/reports/getOneDriveUsageAccountDetail` |
| 10 | MS Teams | `/teams` |
| 11 | SharePoint | `/sites?search=*` |
| 12 | SharePoint Subsites | `/sites/{id}/sites` |
| 13 | External Sharing | `/users?$filter=userType eq 'Guest'` |
| 14 | Apps | `/applications` |
| 15 | Hardware | `/deviceManagement/managedDevices` (Intune) / `/devices` (Entra fallback) |
| 16 | Telephony | `/users` (phone fields) |
| 17 | HighLevel Summary | Calculated from all above |

---

## Support Resources

- [Microsoft Graph API Reference](https://learn.microsoft.com/en-us/graph/api/overview)
- [Azure App Registration Guide](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [Certificate-Based Authentication](https://learn.microsoft.com/en-us/azure/active-directory/develop/active-directory-certificate-credentials)
- [Graph Explorer (test API calls)](https://developer.microsoft.com/en-us/graph/graph-explorer)
- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
