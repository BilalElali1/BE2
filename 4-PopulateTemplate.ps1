# 4-PopulateTemplate.ps1
# Script to populate IT M&A Discovery Workbook Template from normalized CSV files
# Author: BilalElali1
# Date: 2026-03-22

# Load required modules
Import-Module ImportExcel

# Define paths
$csvDirectory = "Output/csv_diagnostics/"
$excelTemplatePath = "IT M&A Discovery Workbook Template.xlsx"
$highLevelSummarySheet = "HighLevel Summary"
$logFilePath = "C:\Path\To\Your\Logs\population_log.txt"

# Initialize logging function
function Log-Message {
    param (
        [string]$message
    )
    Add-Content -Path $logFilePath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message"
}

# Load the Excel file
$excelPackage = Open-ExcelPackage -Path $excelTemplatePath

# Read normalized CSV files and populate sheets
foreach ($csvFile in Get-ChildItem -Path $csvDirectory -Filter *.csv) {
    $worksheetName = $csvFile.BaseName
    $csvData = Import-Csv -Path $csvFile.FullName

    if ($excelPackage.Workbook.Worksheets[$worksheetName]) {
        # Map data to existing worksheet
        $worksheet = $excelPackage.Workbook.Worksheets[$worksheetName]
        $headerMap = @{}
        
        # Assume headers are on row 3 in the worksheet
        $row3Headers = $worksheet.Cells[3, 1, 3, $worksheet.Dimension.End.Column] | ForEach-Object { $_.Text }
        
        # Create header map
        foreach ($header in $row3Headers) {
            $headerMap[$header] = $header
        }

        # Populate data below row 3
        $rowIndex = 4
        foreach ($row in $csvData) {
            foreach ($header in $headerMap.Keys) {
                $columnIndex = [array]::IndexOf($row3Headers, $header) + 1
                if ($columnIndex -gt 0) {
                    $worksheet.Cells[$rowIndex, $columnIndex].Value = $row.$header
                }
            }
            $rowIndex++
        }
        Log-Message "Populated worksheet '$worksheetName' from '$($csvFile.Name)'."
    } else {
        Log-Message "Worksheet '$worksheetName' does not exist in the template."
    }
}

# Build HighLevel Summary worksheet
# (Logic to count and totals for all worksheet types goes here...)

# Save the modified workbook
Close-ExcelPackage $excelPackage
Log-Message "Excel file saved successfully with all updates."

# Complete logging
Log-Message "Data population completed."