<#
.SYNOPSIS
This script fetches Microsoft Graph Reports for usage/activity metrics, including OneDrive, SharePoint, and Teams.
.DESCRIPTION
The script authenticates using Registered App Auth with Certificate Thumbprint, normalizes header variations, and outputs the result to a CSV file.
#>

# Variables
$TenantId = "<Your-Tenant-ID>"
$AppId = "<Your-Application-ID>"
$Thumbprint = "<Your-Certificate-Thumbprint>"
$OutputPath = "./Output/csv_diagnostics/usage_reports.csv"

# Function to Get Access Token
Function Get-AccessToken {
    param(
        [string]$TenantId,
        [string]$AppId,
        [string]$Thumbprint
    )

    $cert = Get-Item Cert:\CurrentUser\My\$Thumbprint
    $body = @{ 
        grant_type = "client_credentials"
        client_id = $AppId
        scope = "https://graph.microsoft.com/.default"
    }

    $response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method Post -Body $body -Certificate $cert
    return $response.access_token
}

# Fetch Reports
Function Get-GraphReports {
    $token = Get-AccessToken -TenantId $TenantId -AppId $AppId -Thumbprint $Thumbprint

    $reportUrls = @( 
        "https://graph.microsoft.com/v1.0/reports/getOneDriveUsageDetail(period='D7')",
        "https://graph.microsoft.com/v1.0/reports/getSharePointActivityFileCounts(period='D7')",
        "https://graph.microsoft.com/v1.0/reports/getTeamsUserActivityCounts(period='D7')"
    )

    $results = @()
    foreach ($url in $reportUrls) {
        $response = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $token" }
        $results += $response
    }

    return $results
}

# Normalize Headers and Export to CSV
Function Export-ReportsToCSV {
    $reports = Get-GraphReports
    $normalizedReports = @() 
    foreach ($report in $reports) {
        $normalizedReport = [PSCustomObject]@{}
        foreach ($property in $report.PSObject.Properties) {
            $normalizedReport | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
        }
        $normalizedReports += $normalizedReport
    }
    $normalizedReports | Export-Csv -Path $OutputPath -NoTypeInformation
}

# Execute the script
Export-ReportsToCSV
