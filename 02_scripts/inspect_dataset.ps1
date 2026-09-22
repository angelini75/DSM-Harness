<#
.SYNOPSIS
    Inspect and profile dataset structure (.xlsx or .csv) natively on Windows without Python.
.DESCRIPTION
    Zero-dependency profiler using .NET ZipFile to read Excel sheets and columns.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

if (-not (Test-Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

$ext = [System.IO.Path]::GetExtension($FilePath).ToLower()

if ($ext -eq ".csv") {
    $data = Import-Csv -Path $FilePath | Select-Object -First 3
    if ($data.Count -gt 0) {
        $cols = $data[0].PSObject.Properties.Name
        Write-Host "=== CSV DATASET INSPECTION ===" -ForegroundColor Cyan
        Write-Host "File: $FilePath"
        Write-Host "Columns ($($cols.Count)): $($cols -join ', ')"
        Write-Host "`nSample values (first row):"
        foreach ($c in $cols) {
            Write-Host "  * $c = $($data[0].$c)"
        }
    }
} elseif ($ext -in @(".xlsx", ".xls")) {
    # If Rscript is available, we can also use inspect_dataset.R
    # But let's read the OpenXML directly via .NET ZipFile (100% native Windows, 0 dependencies)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $FilePath).Path)
    
    # 1. Read shared strings
    $sharedStrings = @()
    $sstEntry = $zip.GetEntry("xl/sharedStrings.xml")
    if ($sstEntry) {
        $reader = New-Object System.IO.StreamReader($sstEntry.Open())
        $xmlContent = $reader.ReadToEnd()
        $reader.Close()
        [xml]$sstXml = $xmlContent
        $ns = New-Object System.Xml.XmlNamespaceManager($sstXml.NameTable)
        $ns.AddNamespace("m", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
        $siNodes = $sstXml.SelectNodes("//m:si", $ns)
        foreach ($node in $siNodes) {
            $sharedStrings += $node.InnerText
        }
    }
    
    # 2. Read workbook.xml for sheet names
    $wbEntry = $zip.GetEntry("xl/workbook.xml")
    $reader = New-Object System.IO.StreamReader($wbEntry.Open())
    [xml]$wbXml = $reader.ReadToEnd()
    $reader.Close()
    $wbNs = New-Object System.Xml.XmlNamespaceManager($wbXml.NameTable)
    $wbNs.AddNamespace("m", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
    $sheetNodes = $wbXml.SelectNodes("//m:sheet", $wbNs)
    
    Write-Host "=== EXCEL DATASET INSPECTION (Native Windows) ===" -ForegroundColor Cyan
    Write-Host "File: $FilePath"
    Write-Host "Total Sheets: $($sheetNodes.Count)"
    
    $sheetIndex = 1
    foreach ($s in $sheetNodes) {
        $sheetName = $s.GetAttribute("name")
        $sheetEntry = $zip.GetEntry("xl/worksheets/sheet$sheetIndex.xml")
        Write-Host "`n--- Sheet: '$sheetName' ---" -ForegroundColor Yellow
        
        if ($sheetEntry) {
            $reader = New-Object System.IO.StreamReader($sheetEntry.Open())
            [xml]$sheetXml = $reader.ReadToEnd()
            $reader.Close()
            $sNs = New-Object System.Xml.XmlNamespaceManager($sheetXml.NameTable)
            $sNs.AddNamespace("m", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
            
            # Row 1 (headers)
            $headerRow = $sheetXml.SelectSingleNode("//m:row[@r='1']", $sNs)
            if ($headerRow) {
                $cols = @()
                foreach ($c in $headerRow.SelectNodes("m:c", $sNs)) {
                    $t = $c.GetAttribute("t")
                    $val = $c.InnerText
                    if ($t -eq "s" -and $val -match "^\d+$") {
                        $val = $sharedStrings[[int]$val]
                    }
                    $cols += $val
                }
                Write-Host "Columns ($($cols.Count)): $($cols -join ', ')"
                
                # Row 2 (first sample row)
                $sampleRow = $sheetXml.SelectSingleNode("//m:row[@r='2']", $sNs)
                if ($sampleRow) {
                    Write-Host "Sample values (Row 2):"
                    $cNodes = $sampleRow.SelectNodes("m:c", $sNs)
                    for ($i = 0; $i -lt [Math]::Min($cols.Count, $cNodes.Count); $i++) {
                        $c = $cNodes[$i]
                        $t = $c.GetAttribute("t")
                        $val = $c.InnerText
                        if ($t -eq "s" -and $val -match "^\d+$") {
                            $val = $sharedStrings[[int]$val]
                        }
                        Write-Host "  * $($cols[$i]) = $val"
                    }
                }
            } else {
                Write-Host "(Sheet appears empty)"
            }
        }
        $sheetIndex++
    }
    
    $zip.Dispose()
} else {
    Write-Host "Unsupported file extension: $ext" -ForegroundColor Red
}
