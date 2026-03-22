# M365 MA Discovery – Setup Instructions

## Prerequisites

- PowerShell 5.1 or later
- An Azure AD application registration with:
  - A self-signed certificate uploaded to the app
  - Microsoft Graph API permissions (with admin consent)

---

## Step 1 – Configure config.json

1. Copy the example file:
   ```
   copy config.json.example config.json
   ```
2. Open `config.json` and fill in your values:
   ```json
   {
     "TenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
     "ClientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
     "CertificateThumbprint": "ABCDEF1234567890..."
   }
   ```

---

## Step 2 – Verify Required File Locations

All files must be placed in the same folder (e.g. `C:\Down\Scripts\All\M365Discovery\`).

### Expected directory structure

```
M365Discovery\
├── run-all.ps1                         ← master orchestration script
├── config.json                         ← your credentials (fill in Step 1)
├── config.json.example                 ← template (keep as reference)
├── IT M&A Discovery Workbook Template.xlsx
├── SETUP_INSTRUCTIONS.md
├── modules\
│   └── Auth.psm1
└── scripts\
    ├── 1-FullExport-v6.ps1
    ├── 2-GraphReports-v9.ps1
    ├── 3-MergeLogs.ps1
    └── 4-PopulateTemplate.ps1
```

> **Note:** `run-all.ps1` also accepts the individual scripts placed directly in the root folder
> (alongside `run-all.ps1`) as a fallback if the `scripts\` subfolder is not present.

---

## Step 3 – Run the Pipeline

Open PowerShell, `cd` to your M365Discovery folder, then run:

```powershell
.\run-all.ps1
```

Or specify an alternate config file:

```powershell
.\run-all.ps1 -ConfigPath "C:\Secure\my-config.json"
```

---

## Step 4 – Check Output

| Location | Contents |
|---|---|
| `Output\` | CSV exports and the final Excel workbook |
| `logs\run-all.log` | Timestamped execution log |

The final workbook is named:
```
IT_MA_Discovery_Workbook_Populated_YYYY-MM-DD_HH-MM-SS.xlsx
```

---

## Troubleshooting

| Error | Fix |
|---|---|
| `Conversion from JSON failed … Invalid property identifier character: \` | `config.json` was saved with literal `\n` instead of real newlines. Delete it and re-copy from `config.json.example`. |
| `.\FullExport-v6.ps1 is not recognized` | Script is missing or misnamed. Verify the `scripts\` folder contains `1-FullExport-v6.ps1`. |
| `config.json not found` | Run `.\run-all.ps1` from inside the M365Discovery folder, or pass `-ConfigPath` explicitly. |
