# ==========================================
# Kerää järjestelmätiedot
# ==========================================
try {
    $computerName = $env:COMPUTERNAME
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $osName = $os.Caption
    $osVersion = $os.Version
    $osBuild = $os.BuildNumber

    $cpu = Get-CimInstance -ClassName Win32_Processor
    $processorName    = $cpu.Name
    $processorCores   = $cpu.NumberOfCores
    $processorThreads = $cpu.ThreadCount

    $totalMemory = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    $MemorySpeed = (Get-CimInstance -ClassName Win32_PhysicalMemory |  Select-Object -First 1 -ExpandProperty Speed)
    $Memory = Get-CimInstance -ClassName Win32_PhysicalMemory
    $MemoryCount = $Memory.count

    $gpu        = Get-CimInstance -ClassName Win32_VideoController
    $gpuName    = $gpu[0].Name

    $motherboard = Get-CimInstance -ClassName Win32_BaseBoard
    $motherboardManufacturer = $motherboard.Manufacturer
    $motherboardProduct = $motherboard.Product


    $bios                = Get-CimInstance -ClassName Win32_BIOS
    $biosInfoManufacturer = $bios.Manufacturer
    $biosInfoVersion      = $bios.BIOSVersion
    $biosInfoReleaseDate  = $bios.ReleaseDate

    # Käyttäjän kansion koko
    $currentUserPath  = $env:USERPROFILE
    $userFolderSize   = (Get-ChildItem -Path $currentUserPath -Recurse -File -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum).Sum
    $userFolderSizeGB = [math]::Round($userFolderSize / 1GB, 2)

    $bootTime = $os.LastBootUpTime

    # Loogiset levyt (3=kiintolevy, 4=verkko)
    $logicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk

    # Fyysiset levyt firmware-tiedoilla
    $physicalDisks = @{}
    Get-PhysicalDisk | ForEach-Object {
        $diskNumber = ($_ | Get-Disk).Number
        try {
            $firmware = Get-CimInstance -Namespace root\Microsoft\Windows\Storage -ClassName MSFT_PhysicalDisk |
                        Where-Object DeviceId -EQ $diskNumber |
                        Select-Object -ExpandProperty FirmwareVersion
        } catch {
            $firmware = "Ei saatavilla"
        }
        $physicalDisks[$diskNumber] = @{
            BusType         = $_.BusType
            MediaType       = $_.MediaType
            Model           = $_.FriendlyName
            HealthStatus    = $_.HealthStatus.ToString()
            FirmwareVersion = $firmware
        }
    }

    $currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}
catch {
    Write-Error "Virhe järjestelmätietojen hakemisessa: $_"
    exit 1
}

# ==========================================
# Alustetaan HTML ja lisätään head + tyylit
# ==========================================
$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Computer Information</title>
 
    <style>
        /* Google Fonts */
        @import url('https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&family=Merriweather:wght@400;700&display=swap');

        /* Base styles */
        body { font-family: 'Roboto', sans-serif; background-color: #fcfcfc; margin:0; padding:20px; color:#333; }
        h1, h2, p { font-family: 'Merriweather', serif; text-align:center; margin-bottom:20px; }

        /* Table styles */
        table { margin:20px auto; width:80%; max-width:700px; border-collapse:collapse; background:#fff; }
        table, th, td { border:1px solid #ccc; }
        th, td { padding:10px; text-align:left; }
        table:nth-of-type(1) th:first-child, table:nth-of-type(1) td:first-child { background:#e0e0e0; font-weight:bold; width:40%; }
        table tr:first-child th { background:#e0e0e0; font-weight:bold; text-align:center; }
        @media screen and (max-width:600px) { table { width:95%; } }

        /* Card layout */
        .cards-container {
        display: flex;
        flex-wrap: wrap;
        justify-content: center;
        gap: 20px;
        margin: 30px auto;
        width: 90%;
        max-width: 1200px;
        }

        .card { background:#fff; border:1px solid #ddd; border-radius:8px; padding:16px; width:300px; box-shadow:0 2px 6px rgba(0,0,0,0.05); transition:box-shadow .2s ease, transform .2s ease; }
        .card:hover { box-shadow:0 4px 10px rgba(0,0,0,0.1); transform:scale(1.02); }
        .card-header { display:flex; justify-content:space-between; align-items:flex-start; }
        .card-texts { flex:1; }
        .card-texts p { margin:4px 0; }
        .card-chart { margin-left:12px; }

        /* Details toggle */
        .details { max-height:0; overflow:hidden; transition:max-height .3s ease, opacity .3s ease; opacity:0; }
        .details.show { max-height:200px; opacity:1; }

        /* Button */
        button { background:#007bff; color:#fff; border:none; border-radius:6px; padding:8px 12px; cursor:pointer; margin-top:10px; transition:background .2s ease, transform .2s ease; }
        button:hover { background:#0056b3; transform:scale(1.03); }

        /* Pie chart SVG */
        .pie { display:block; margin:auto 0; }

        /* Footer */
        footer { text-align:center; margin-top:40px; font-size:0.9em; color:#666; }
    </style>

</head>
<body>
    <h1>Computer Information</h1>
    <table>
        <tr><th>Computer Name</th><td>$computerName</td></tr>
        <tr><th>OS Name</th><td>$osName</td></tr>
        <tr><th>OS Version</th><td>$osVersion</td></tr>
        <tr><th>OS Build</th><td>$osBuild</td></tr>
        <tr><th>Processor</th><td>$processorName</td></tr>
        <tr><th>Processor Cores</th><td>$processorCores</td></tr>
        <tr><th>Processor Threads</th><td>$processorThreads</td></tr>
        <tr><th>Motherboard valmistaja</th><td>$motherboardManufacturer</td></tr>
        <tr><th>Motherboard Model</th><td>$motherboardProduct</td></tr>
        <tr><th>Total Memory (GB)</th><td>$totalMemory</td></tr>
        <tr><th>Memory Speed (MHz)</th><td>$MemorySpeed</td></tr>
        <tr><th>Memory Modules</th><td>$MemoryCount</td></tr>
        <tr><th>GPU</th><td>$gpuName</td></tr>
        <tr><th>BIOS Manufacturer</th><td>$biosInfoManufacturer</td></tr>
        <tr><th>BIOS Version</th><td>$biosInfoVersion</td></tr>
        <tr><th>BIOS Release date</th><td>$biosInfoReleaseDate</td></tr>
        <tr><th>Last Boot time</th><td>$bootTime</td></tr>
    </table>

    <h2>Current User Folder Size</h2>
    <table>
        <tr><th>User</th><th>Size (GB)</th></tr>
        <tr><td>$env:USERNAME</td><td>$userFolderSizeGB</td></tr>
    </table>
        <div class='cards-container'>

"@

# ==========================================
# Looppi: levyosioiden kortit
# ==========================================
$counter = 0
foreach ($disk in $logicalDisks) {
    if (-not ($disk.Size -and $disk.FreeSpace)) { continue }

    $counter++
    # Muunnokset gigatavuiksi ja SVG-laskelmat
    $sizeGB   = [math]::Round($disk.Size / 1GB, 2)
    $freeGB   = [math]::Round($disk.FreeSpace / 1GB, 2)
    $usedGB   = [math]::Round($sizeGB - $freeGB, 2)
    $usagePct = [math]::Round(($usedGB / $sizeGB) * 100, 1)
    $angle    = [math]::Round(360 * ($usedGB / $sizeGB), 1)
    $largeArc = if ($angle -gt 180) { 1 } else { 0 }
    $x        = [math]::Round(18 + 16 * [math]::Sin($angle * [math]::PI/180), 2)
    $y        = [math]::Round(18 - 16 * [math]::Cos($angle * [math]::PI/180), 2)
    $volumeName = if ($disk.VolumeName) { $disk.VolumeName } else { "Ei nimeä" }

    $chartSvg = @"
<svg width='80' height='80' viewBox='0 0 36 36'>
  <circle cx='18' cy='18' r='16' fill='#eee'/>
  <path d='M18 2 A16 16 0 $largeArc 1 $x $y L18 18 Z' fill='#007bff'/>
  <text x='18' y='22' font-size='8' text-anchor='middle'>$usagePct`%</text>
</svg>
"@

    # Verkko­jaot (DriveType 4) vs. paikalliset (3)
    if ($disk.DriveType -eq 4) {
        $html += @"
    <div class='card'>
      <p><strong>Disk:</strong> $($disk.DeviceID) (network share)</p>
      <p><strong>Name:</strong> $volumeName</p>
      <p><strong>Size:</strong> $sizeGB GB</p>
      <p><em>Physical data is not available for network share.</em></p>
      <div class='card-chart'>$chartSvg</div>

        </div>
"@
        continue
    }

    # Paikalliset osiot: haetaan fyysisen levyn tiedot
    try {
        $driveLetter = $disk.DeviceID.TrimEnd(':')
        $diskNumber  = (Get-Partition -DriveLetter $driveLetter | Get-Disk).Number
        $info        = $physicalDisks[$diskNumber]
        $busType     = $info.BusType
        $mediaType   = if ($info.MediaType -and $info.MediaType -ne 'Unspecified') { $info.MediaType }
                       else { switch ($busType) { 'SATA' {'HDD'} 'SAS' {'HDD'} 'NVMe' {'SSD (NVMe)'} default {''} } }
        $model       = $info.Model
        $health      = $info.HealthStatus
        $firmware    = $info.FirmwareVersion
    }
    catch {
        $busType = $mediaType = $model = $health = $firmware = 'Ei saatavilla'
    }

    $html += @"
    <div class='card'>
      <p><strong>Disk:</strong> $($disk.DeviceID)</p>
      <p><strong>Name:</strong> $volumeName</p>
      <p><strong>Size:</strong> $sizeGB GB</p>
      <p><strong>Free:</strong> $freeGB GB</p>
      <p><strong>Used:</strong> $usedGB GB ($usagePct`%)</p>
      <p><strong>Disk type:</strong> $busType $mediaType</p>
      <p><strong>Model:</strong> $model</p>
      <p><strong>Health:</strong> $health</p>
      <p><strong>Firmware:</strong> $firmware</p>
            <div class='card-chart'>$chartSvg</div>
    </div>
           
"@
}

# ==========================================
# Lopetus: footeri ja sulkevat tagit
# ==========================================
$html += @"
</div>
    <footer>
        <p>&copy; 2025 Juha Hokkanen. Updated: $currentDateTime</p>
    </footer>
</body>
</html>
"@

# ==========================================
# Tallennus ja GitHub-push
# ==========================================
$localRepoPath    = "C:\Koodit\scriptit\TotalPCInfo"
$destinationFolder = Join-Path $localRepoPath docs
$htmlPath         = Join-Path $destinationFolder index.html

if (-not (Test-Path $destinationFolder)) {
    New-Item -Path $destinationFolder -ItemType Directory | Out-Null
}

$html | Out-File -FilePath $htmlPath -Encoding utf8
Set-Location $localRepoPath
git add docs/index.html
git commit -m "Päivitetty index.html – $currentDateTime"
git push origin main

Write-Host "HTML-sivu generoitu ja pusattu GitHubiin: $htmlPath"

Write-Host "`n🌐 Raportti julkaistu: https://juhahokkanen.github.io/TotalPCInfo/"