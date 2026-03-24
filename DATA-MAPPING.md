# Data Mapping Reference

This document describes how raw Microsoft Graph API data is normalized and mapped into each of the 17 worksheets in `IT M&A Discovery Workbook Template.xlsx`.

---

## Table of Contents

1. [General Mapping Rules](#1-general-mapping-rules)
2. [Microsoft Reporting Quirks](#2-microsoft-reporting-quirks)
3. [Fallback Logic](#3-fallback-logic)
4. [Worksheet-by-Worksheet Mapping](#4-worksheet-by-worksheet-mapping)
   - [1. Identity Summary](#worksheet-1-identity-summary)
   - [2. Activity & Licenses](#worksheet-2-activity--licenses)
   - [3. Domains](#worksheet-3-domains)
   - [4. User MBX](#worksheet-4-user-mbx)
   - [5. Shared MBX](#worksheet-5-shared-mbx)
   - [6. M365 Groups](#worksheet-6-m365-groups)
   - [7. DLs](#worksheet-7-dls)
   - [8. Rooms](#worksheet-8-rooms)
   - [9. OneDrive](#worksheet-9-onedrive)
   - [10. MS Teams](#worksheet-10-ms-teams)
   - [11. SharePoint](#worksheet-11-sharepoint)
   - [12. SharePoint Subsites](#worksheet-12-sharepoint-subsites)
   - [13. External Sharing](#worksheet-13-external-sharing)
   - [14. Apps](#worksheet-14-apps)
   - [15. Hardware](#worksheet-15-hardware)
   - [16. Telephony](#worksheet-16-telephony)
   - [17. HighLevel Summary](#worksheet-17-highlevel-summary)
5. [HighLevel Summary Calculation Logic](#5-highlevel-summary-calculation-logic)

---

## 1. General Mapping Rules

### CSV Header Naming Convention

All CSV files use **PascalCase** headers with no spaces. These map to Excel column headers in row 3 of each worksheet.

| CSV Header | Excel Column Header | Notes |
|---|---|---|
| `DisplayName` | Display Name | Direct map |
| `UserPrincipalName` | User Principal Name (UPN) | Direct map |
| `AccountEnabled` | Account Enabled | Boolean → `True`/`False` |
| `CreatedDateTime` | Created Date | ISO 8601 → `yyyy-MM-dd` |
| `LastSignInDateTime` | Last Sign-In | ISO 8601 → `yyyy-MM-dd` or `Never` |

### Null and Empty Value Handling

- `null` API values → empty string `""` in CSV
- Missing properties → empty string `""`
- Boolean `false` → `"False"` (string), not `0`
- Date values that are `null` → `"Never"` where semantically appropriate (e.g., LastSignIn)

### Pagination

All Graph API list endpoints return a maximum of 999 results per page. Scripts automatically follow `@odata.nextLink` until all pages are retrieved:

```
GET /users?$top=999
→ { "value": [...], "@odata.nextLink": "https://graph.microsoft.com/v1.0/users?$skiptoken=..." }
→ Follow nextLink until no more pages
```

---

## 2. Microsoft Reporting Quirks

### Header Name Variations in Reports API

The Microsoft Graph Reports API (e.g., `getOneDriveUsageAccountDetail`) returns CSV with header names that vary between tenants and API versions. The scripts normalize these using a header alias map:

| Possible API Header | Normalized CSV Header |
|---|---|
| `User Principal Name` | `UserPrincipalName` |
| `User Display Name` | `DisplayName` |
| `Is Deleted` | `IsDeleted` |
| `Deleted Date` | `DeletedDate` |
| `Last Activity Date` | `LastActivityDate` |
| `Storage Used (Byte)` | `StorageUsedBytes` |
| `Storage Allocated (Byte)` | `StorageAllocatedBytes` |
| `File Count` | `FileCount` |
| `Active File Count` | `ActiveFileCount` |
| `Site URL` | `SiteUrl` |
| `Owner Display Name` | `OwnerDisplayName` |
| `Owner Principal Name` | `OwnerPrincipalName` |

### Date Format Normalization

Reports API returns dates in `MM/DD/YYYY` format. All dates are normalized to `YYYY-MM-DD` (ISO 8601) for consistency.

### Obfuscated User Data

Tenants with privacy settings enabled may return obfuscated UPNs (e.g., `8b6bc30e-c01c-4b30-9ef7-3e5d14aafcf0`). The scripts attempt to correlate with `/users` endpoint data to resolve display names.

---

## 3. Fallback Logic

### OneDrive URL Fallback

OneDrive sites may not appear in the `/reports/getOneDriveUsageAccountDetail` endpoint if there has been no recent activity. In that case, the URL is constructed from the user's UPN:

```
Primary: URL from getOneDriveUsageAccountDetail report
Fallback: Constructed as https://<tenant>-my.sharepoint.com/personal/<upn_normalized>
          where upn_normalized = UPN with '@' → '_' and '.' → '_'

Example:
  UPN: john.smith@contoso.com
  URL: https://contoso-my.sharepoint.com/personal/john_smith_contoso_com
```

### Hardware: Intune vs. Entra Fallback

The Hardware worksheet prefers **Intune** (`/deviceManagement/managedDevices`) as the data source. If the tenant does not have Intune licensing or the permission is not granted, the script falls back to **Entra ID registered devices** (`/devices`):

```
Primary source:  GET /deviceManagement/managedDevices
  Fields: deviceName, operatingSystem, osVersion, serialNumber,
          userDisplayName, userPrincipalName, enrolledDateTime,
          lastSyncDateTime, complianceState, managementState

Fallback source: GET /devices
  Fields: displayName, operatingSystem, operatingSystemVersion,
          registrationDateTime, approximateLastSignInDateTime,
          isCompliant, isManaged, trustType
```

The `DataSource` column in the Hardware CSV indicates which source was used (`Intune` or `Entra`).

### Last Sign-In Fallback

User sign-in data requires `AuditLog.Read.All`. If this permission is not available:
- `LastSignInDateTime` → `"Unknown"`
- `LastNonInteractiveSignInDateTime` → `"Unknown"`

---

## 4. Worksheet-by-Worksheet Mapping

### Worksheet 1: Identity Summary

**Graph Endpoint:** `GET /users?$select=...&$top=999`

**CSV File:** `Output/csv_diagnostics/IdentitySummary.csv`

| CSV Column | Graph Property | Notes |
|---|---|---|
| `DisplayName` | `displayName` | |
| `UserPrincipalName` | `userPrincipalName` | |
| `GivenName` | `givenName` | |
| `Surname` | `surname` | |
| `JobTitle` | `jobTitle` | |
| `Department` | `department` | |
| `OfficeLocation` | `officeLocation` | |
| `CompanyName` | `companyName` | |
| `AccountEnabled` | `accountEnabled` | `True`/`False` |
| `UserType` | `userType` | `Member`/`Guest` |
| `CreatedDateTime` | `createdDateTime` | Normalized to `yyyy-MM-dd` |
| `Mail` | `mail` | |
| `ProxyAddresses` | `proxyAddresses` | Semicolon-separated |
| `OnPremisesSyncEnabled` | `onPremisesSyncEnabled` | `True`/`False`/`""` |
| `OnPremisesDomainName` | `onPremisesDomainName` | |
| `AssignedLicenses` | `assignedLicenses` | Count of license SKUs |
| `Id` | `id` | Azure AD Object ID |

---

### Worksheet 2: Activity & Licenses

**Graph Endpoints:**
- `GET /users?$select=...&$top=999`
- `GET /reports/getOffice365ActiveUserDetail(period='D30')`

**CSV File:** `Output/csv_diagnostics/ActivityLicenses.csv`

| CSV Column | Source | Notes |
|---|---|---|
| `UserPrincipalName` | `/users` → `userPrincipalName` | Join key |
| `DisplayName` | `/users` → `displayName` | |
| `LastSignInDateTime` | `/users` → `signInActivity.lastSignInDateTime` | Requires `AuditLog.Read.All` |
| `LastNonInteractiveSignIn` | `/users` → `signInActivity.lastNonInteractiveSignInDateTime` | |
| `AssignedLicenses` | `/users` → `assignedLicenses` | License SKU IDs, semicolon-separated |
| `LicenseCount` | Calculated | Count of `assignedLicenses` array |
| `HasExchangeLicense` | Calculated | `True` if any Exchange SKU present |
| `HasTeamsLicense` | Calculated | `True` if any Teams SKU present |
| `IsActive30Days` | Reports API | `True` if active in last 30 days |
| `ExchangeLastActivity` | Reports API | Date of last Exchange activity |
| `OneDriveLastActivity` | Reports API | Date of last OneDrive activity |
| `SharePointLastActivity` | Reports API | Date of last SharePoint activity |
| `TeamsLastActivity` | Reports API | Date of last Teams activity |

---

### Worksheet 3: Domains

**Graph Endpoint:** `GET /domains`

**CSV File:** `Output/csv_diagnostics/Domains.csv`

| CSV Column | Graph Property | Notes |
|---|---|---|
| `DomainName` | `id` | The domain FQDN |
| `IsDefault` | `isDefault` | `True`/`False` |
| `IsInitial` | `isInitial` | `True` for `*.onmicrosoft.com` domain |
| `IsVerified` | `isVerified` | `True`/`False` |
| `AuthenticationType` | `authenticationType` | `Managed` or `Federated` |
| `SupportedServices` | `supportedServices` | Semicolon-separated (e.g., `Email;OfficeCommunicationsOnline`) |

---

### Worksheet 4: User MBX

**Graph Endpoint:** `GET /users?$filter=assignedLicenses/any(x:x/skuId ne null)&$select=...`

**CSV File:** `Output/csv_diagnostics/UserMBX.csv`

| CSV Column | Graph Property | Notes |
|---|---|---|
| `DisplayName` | `displayName` | |
| `UserPrincipalName` | `userPrincipalName` | |
| `Mail` | `mail` | Primary SMTP address |
| `ProxyAddresses` | `proxyAddresses` | All SMTP addresses, semicolon-separated |
| `MailboxType` | Calculated | `"UserMailbox"` for licensed users |
| `AccountEnabled` | `accountEnabled` | |
| `LitigationHoldEnabled` | Extended property | From Exchange Online via Graph |
| `ArchiveStatus` | Extended property | `None`/`Active`/`Provisioning` |
| `RecipientTypeDetails` | Extended property | Mailbox recipient type |
| `HiddenFromGAL` | `showInAddressList` | Inverted: `True` if `showInAddressList = false` |

---

### Worksheet 5: Shared MBX

**Graph Endpoint:** `GET /users?$filter=userType eq 'Member'&$select=...` (filtered by `assignedLicenses` empty)

**CSV File:** `Output/csv_diagnostics/SharedMBX.csv`

| CSV Column | Graph Property | Notes |
|---|---|---|
| `DisplayName` | `displayName` | |
| `UserPrincipalName` | `userPrincipalName` | |
| `Mail` | `mail` | |
| `AccountEnabled` | `accountEnabled` | Shared MBX are typically disabled accounts |
| `ProxyAddresses` | `proxyAddresses` | Semicolon-separated |
| `HiddenFromGAL` | `showInAddressList` | Inverted |
| `MailboxType` | Hardcoded | `"SharedMailbox"` |

---

### Worksheet 6: M365 Groups

**Graph Endpoint:** `GET /groups?$filter=groupTypes/any(c:c eq 'Unified')&$select=...`

**CSV File:** `Output/csv_diagnostics/M365Groups.csv`

| CSV Column | Graph Property | Notes |
|---|---|---|
| `DisplayName` | `displayName` | |
| `Mail` | `mail` | |
| `Description` | `description` | |
| `CreatedDateTime` | `createdDateTime` | Normalized to `yyyy-MM-dd` |
| `Visibility` | `visibility` | `Public`/`Private` |
| `MemberCount` | `$count` expand | Requires `$count=true` header |
| `ResourceBehaviorOptions` | `resourceBehaviorOptions` | Semicolon-separated |
| `GroupTypes` | `groupTypes` | Semicolon-separated |
| `IsAssignableToRole` | `isAssignableToRole` | |
| `Id` | `id` | |

---

### Worksheet 7: DLs

**Graph Endpoint:** `GET /groups?$filter=not groupTypes/any(c:c eq 'Unified') and mailEnabled eq true and securityEnabled eq false`

**CSV File:** `Output/csv_diagnostics/DLs.csv`

| CSV Column | Graph Property | Notes |
|---|---|---|
| `DisplayName` | `displayName` | |
| `Mail` | `mail` | |
| `Description` | `description` | |
| `MemberCount` | `$count` expand | |
| `HiddenFromGAL` | `hideFromAddressLists` | |
| `CreatedDateTime` | `createdDateTime` | |
| `Id` | `id` | |

---

### Worksheet 8: Rooms

**Graph Endpoint:** `GET /users?$filter=userType eq 'Member'` (filtered by `assignedPlans` containing room resource)

Also: `GET /places/microsoft.graph.room`

**CSV File:** `Output/csv_diagnostics/Rooms.csv`

| CSV Column | Graph Property | Notes |
|---|---|---|
| `DisplayName` | `displayName` | |
| `UserPrincipalName` | `userPrincipalName` | |
| `Mail` | `mail` | |
| `Building` | `building` | From `/places` endpoint |
| `Capacity` | `capacity` | Number of people |
| `FloorNumber` | `floorNumber` | |
| `IsWheelChairAccessible` | `isWheelChairAccessible` | |
| `Phone` | `phone` | Room phone number |
| `AccountEnabled` | `accountEnabled` | |

---

### Worksheet 9: OneDrive

**Graph Endpoint:** `GET /reports/getOneDriveUsageAccountDetail(period='D180')`

**CSV File:** `Output/csv_diagnostics/OneDrive.csv`

| CSV Column | Report Column | Notes |
|---|---|---|
| `UserPrincipalName` | `User Principal Name` | Normalized from report header |
| `DisplayName` | `User Display Name` | |
| `SiteUrl` | `Site URL` | Full OneDrive URL; fallback constructed if empty |
| `IsDeleted` | `Is Deleted` | |
| `LastActivityDate` | `Last Activity Date` | `yyyy-MM-dd` |
| `FileCount` | `File Count` | |
| `ActiveFileCount` | `Active File Count` | |
| `StorageUsedBytes` | `Storage Used (Byte)` | Raw bytes |
| `StorageUsedGB` | Calculated | `StorageUsedBytes / 1073741824`, 2 decimal places |
| `StorageAllocatedBytes` | `Storage Allocated (Byte)` | |
| `StorageAllocatedGB` | Calculated | `StorageAllocatedBytes / 1073741824`, 2 decimal places |

---

### Worksheet 10: MS Teams

**Graph Endpoint:** `GET /teams?$select=...` (via `/groups?$filter=resourceProvisioningOptions/Any(x:x eq 'Team')`)

**CSV File:** `Output/csv_diagnostics/MSTeams.csv`

| CSV Column | Graph Property | Notes |
|---|---|---|
| `DisplayName` | `displayName` | |
| `Description` | `description` | |
| `Visibility` | `visibility` | `Public`/`Private` |
| `IsArchived` | `isArchived` | |
| `MemberCount` | Calculated | Count from `GET /teams/{id}/members` |
| `OwnerCount` | Calculated | Count of members with role `owner` |
| `GuestCount` | Calculated | Count of members with `userType eq 'Guest'` |
| `CreatedDateTime` | `createdDateTime` | |
| `WebUrl` | `webUrl` | Link to team in Teams |
| `Id` | `id` | |

---

### Worksheet 11: SharePoint

**Graph Endpoint:** `GET /sites?search=*`

**CSV File:** `Output/csv_diagnostics/SharePoint.csv`

| CSV Column | Graph Property | Notes |
|---|---|---|
| `DisplayName` | `displayName` | |
| `Name` | `name` | URL segment name |
| `WebUrl` | `webUrl` | Full SharePoint URL |
| `Description` | `description` | |
| `CreatedDateTime` | `createdDateTime` | |
| `LastModifiedDateTime` | `lastModifiedDateTime` | |
| `StorageUsedBytes` | `quota.used` | From site quota |
| `StorageUsedGB` | Calculated | |
| `IsPersonalSite` | Calculated | `True` if `-my.sharepoint.com/personal/` in URL |
| `SiteCollectionId` | `id` | |

---

### Worksheet 12: SharePoint Subsites

**Graph Endpoint:** `GET /sites/{site-id}/sites` (for each site in Worksheet 11)

**CSV File:** `Output/csv_diagnostics/SharePointSubsites.csv`

| CSV Column | Graph Property | Notes |
|---|---|---|
| `ParentSiteUrl` | Derived | URL of parent site |
| `DisplayName` | `displayName` | |
| `Name` | `name` | |
| `WebUrl` | `webUrl` | |
| `CreatedDateTime` | `createdDateTime` | |
| `LastModifiedDateTime` | `lastModifiedDateTime` | |
| `Id` | `id` | |

---

### Worksheet 13: External Sharing

**Graph Endpoint:** `GET /users?$filter=userType eq 'Guest'&$select=...`

**CSV File:** `Output/csv_diagnostics/ExternalSharing.csv`

| CSV Column | Graph Property | Notes |
|---|---|---|
| `DisplayName` | `displayName` | |
| `Mail` | `mail` | External email |
| `UserPrincipalName` | `userPrincipalName` | `user@domain_EXT#EXT#@tenant.onmicrosoft.com` |
| `ExternalEmailAddress` | Derived | Decoded from UPN |
| `CreatedDateTime` | `createdDateTime` | |
| `InvitedBy` | `invitedBy.user.displayName` | |
| `AccountEnabled` | `accountEnabled` | |
| `LastSignInDateTime` | `signInActivity.lastSignInDateTime` | |
| `Id` | `id` | |

---

### Worksheet 14: Apps

**Graph Endpoint:** `GET /applications?$select=...`

**CSV File:** `Output/csv_diagnostics/Apps.csv`

| CSV Column | Graph Property | Notes |
|---|---|---|
| `DisplayName` | `displayName` | |
| `AppId` | `appId` | Client ID |
| `CreatedDateTime` | `createdDateTime` | |
| `SignInAudience` | `signInAudience` | `AzureADMyOrg`/`AzureADMultipleOrgs`/`AzureADandPersonalMicrosoftAccount` |
| `PublisherDomain` | `publisherDomain` | |
| `KeyCredentialCount` | Calculated | Count of `keyCredentials` |
| `PasswordCredentialCount` | Calculated | Count of `passwordCredentials` |
| `RequiredResourceAccess` | `requiredResourceAccess` | JSON-encoded API permission list |
| `Tags` | `tags` | Semicolon-separated |
| `Id` | `id` | Object ID |

---

### Worksheet 15: Hardware

**Primary:** `GET /deviceManagement/managedDevices?$select=...`
**Fallback:** `GET /devices?$select=...`

**CSV File:** `Output/csv_diagnostics/Hardware.csv`

| CSV Column | Intune Property | Entra Fallback Property | Notes |
|---|---|---|---|
| `DeviceName` | `deviceName` | `displayName` | |
| `OperatingSystem` | `operatingSystem` | `operatingSystem` | |
| `OsVersion` | `osVersion` | `operatingSystemVersion` | |
| `SerialNumber` | `serialNumber` | `"Unknown"` | Not available in Entra |
| `UserDisplayName` | `userDisplayName` | `"Unknown"` | |
| `UserPrincipalName` | `userPrincipalName` | `"Unknown"` | |
| `EnrolledDateTime` | `enrolledDateTime` | `registrationDateTime` | |
| `LastSyncDateTime` | `lastSyncDateTime` | `approximateLastSignInDateTime` | |
| `ComplianceState` | `complianceState` | `isCompliant` (bool) | |
| `ManagementState` | `managementState` | `isManaged` (bool) | |
| `Manufacturer` | `manufacturer` | `"Unknown"` | |
| `Model` | `model` | `"Unknown"` | |
| `TrustType` | `"Intune"` | `trustType` | |
| `DataSource` | `"Intune"` | `"Entra"` | Indicates source |

---

### Worksheet 16: Telephony

**Graph Endpoint:** `GET /users?$select=displayName,userPrincipalName,businessPhones,mobilePhone,faxNumber,onPremisesExtensionAttributes&$top=999`

**CSV File:** `Output/csv_diagnostics/Telephony.csv`

| CSV Column | Graph Property | Notes |
|---|---|---|
| `DisplayName` | `displayName` | |
| `UserPrincipalName` | `userPrincipalName` | |
| `BusinessPhone` | `businessPhones[0]` | First business phone only |
| `MobilePhone` | `mobilePhone` | |
| `FaxNumber` | `faxNumber` | |
| `ExtensionAttribute1` | `onPremisesExtensionAttributes.extensionAttribute1` | Often used for extension number |
| `ExtensionAttribute2` | `onPremisesExtensionAttributes.extensionAttribute2` | |
| `Department` | `department` | |
| `OfficeLocation` | `officeLocation` | |

---

### Worksheet 17: HighLevel Summary

**Source:** Calculated from all other CSV files.

**CSV File:** `Output/csv_diagnostics/HighLevelSummary.csv`

See [Section 5](#5-highlevel-summary-calculation-logic) for full calculation logic.

| CSV Column | Value |
|---|---|
| `Category` | Category label (e.g., `Users`, `Mailboxes`) |
| `Metric` | Metric name (e.g., `Total Users`) |
| `Value` | Calculated numeric or text value |
| `Notes` | Additional context |

---

## 5. HighLevel Summary Calculation Logic

The HighLevel Summary worksheet is auto-calculated from the exported CSV data:

### Users

| Metric | Calculation |
|---|---|
| Total Users | `COUNT(IdentitySummary.csv)` |
| Enabled Users | `COUNT WHERE AccountEnabled = True` |
| Disabled Users | `COUNT WHERE AccountEnabled = False` |
| Guest Users | `COUNT(ExternalSharing.csv)` |
| Cloud-Only Users | `COUNT WHERE OnPremisesSyncEnabled = ""` |
| Synced (Hybrid) Users | `COUNT WHERE OnPremisesSyncEnabled = True` |

### Mailboxes

| Metric | Calculation |
|---|---|
| User Mailboxes | `COUNT(UserMBX.csv)` |
| Shared Mailboxes | `COUNT(SharedMBX.csv)` |
| Total Mailboxes | `User Mailboxes + Shared Mailboxes` |
| Room Resources | `COUNT(Rooms.csv)` |

### Collaboration

| Metric | Calculation |
|---|---|
| M365 Groups | `COUNT(M365Groups.csv)` |
| Distribution Lists | `COUNT(DLs.csv)` |
| MS Teams | `COUNT(MSTeams.csv)` |
| SharePoint Sites | `COUNT(SharePoint.csv WHERE IsPersonalSite = False)` |
| OneDrive Sites | `COUNT(OneDrive.csv WHERE IsDeleted = False)` |

### Storage

| Metric | Calculation |
|---|---|
| Total OneDrive Storage (GB) | `SUM(OneDrive.StorageUsedGB)` |
| Total SharePoint Storage (GB) | `SUM(SharePoint.StorageUsedGB)` |

### Devices

| Metric | Calculation |
|---|---|
| Total Devices | `COUNT(Hardware.csv)` |
| Intune-Managed Devices | `COUNT WHERE DataSource = Intune` |
| Entra-Registered Devices | `COUNT WHERE DataSource = Entra` |
| Compliant Devices | `COUNT WHERE ComplianceState = Compliant` |

### Security

| Metric | Calculation |
|---|---|
| Registered Apps | `COUNT(Apps.csv)` |
| External Guest Users | `COUNT(ExternalSharing.csv)` |
| Domains | `COUNT(Domains.csv)` |
| Verified Domains | `COUNT WHERE IsVerified = True` |
| Federated Domains | `COUNT WHERE AuthenticationType = Federated` |

### Metadata

| Metric | Value |
|---|---|
| Tenant ID | From `config.json` |
| Export Date | `Get-Date -Format 'yyyy-MM-dd HH:mm:ss'` |
| Exported By | `$env:USERNAME` |
| Script Version | `1-FullExport-v6.ps1` |
| Data Freshness | `Last 180 days (Reports API period)` |
