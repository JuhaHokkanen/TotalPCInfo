# Kerää järjestelmätiedot
try {
    $computerName = $env:COMPUTERNAME
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $osName = $os.Caption
    $osVersion = $os.Version
    $osBuild = $os.BuildNumber

    $cpu = Get-CimInstance -ClassName Win32_Processor
    $processorName = $cpu.Name
    $processorCores = $cpu.NumberOfCores
    $processorThreads = $cpu.ThreadCount

    $totalMemory = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)

    $gpu = Get-CimInstance -ClassName Win32_VideoController
    $gpuName = $gpu[0].Name

    $bios = Get-CimInstance -ClassName Win32_BIOS
    $biosInfoManufacturer = $bios.Manufacturer
    $biosInfoVersion = $bios.BIOSVersion
    $biosInfoReleaseDate = $bios.ReleaseDate

    # Kerää nykyisen käyttäjän kansion koon
    $currentUserPath = $env:USERPROFILE
    $userFolderSize = (Get-ChildItem -Path $currentUserPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $userFolderSizeGB = [math]::Round([double]$userFolderSize / 1GB, 2)

    $bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    
    $physicalDisks = @{}
    Get-PhysicalDisk | ForEach-Object {
        $pdisk      = $_
        $diskNumber = ($pdisk | Get-Disk).Number
    
        try {
            # Yritetään noutaa firmware CIM-instanssista
            $firmware = (Get-CimInstance -Namespace root\Microsoft\Windows\Storage `
                -ClassName MSFT_PhysicalDisk |
                Where-Object DeviceId -EQ $diskNumber).FirmwareVersion
        }
        catch {
            # Jos jotain menee pieleen, merkataan firmware puuttuvaksi
            $firmware = "Ei saatavilla"
        }
    
        # Tallennetaan tiedot hash-taulukkoon levyn numerolla avaimena
        $physicalDisks[$diskNumber] = @{
            BusType         = $pdisk.BusType
            MediaType       = $pdisk.MediaType
            Model           = $pdisk.FriendlyName
            HealthStatus    = $pdisk.HealthStatus.ToString()
            FirmwareVersion = if ($firmware) { $firmware } else { "Ei saatavilla" }
        }
    }
    

    
    # Hanki nykyinen päivämäärä ja kellonaika
    $currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
} catch {
    Write-Host "Virhe järjestelmätietojen hakemisessa: $_"
    exit 1
}

# Luo HTML-sisältö
$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Computer Information</title>

        <style>
/* Tuodaan kaksi eri fonttia Google Fontsista */
@import url('https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&family=Merriweather:wght@400;700&display=swap');

body {
    font-family: 'Roboto', sans-serif; /* Oletusfontti koko sivulle */
    background: linear-gradient(135deg, #f5f7fa, #c3cfe2);
    margin: 0;
    padding: 20px;
    color: #333;
}

/* Muutetaan h1, h2 ja p -fontiksi "Merriweather" */
h1, h2, p {
    font-family: 'Merriweather', serif;
    text-align: center;
    margin-bottom: 20px;
}
    /* Taulukon perusmuotoilu */
    table {
        margin: 20px auto;
        width: 80%;
        max-width: 700px;
        border-collapse: collapse;
        background-color: white;


    }

    table, th, td {
        border: 1px solid black;
    }

    th, td {
        padding: 10px;
        text-align: left;
    }

    /* Ensimmäisen taulukon ensimmäinen sarake (ominaisuuksien nimet) */
    table:nth-of-type(1) th:first-child,
    table:nth-of-type(1) td:first-child {
        background-color: #e0e0e0 !important; /* Harmaa tausta */
        font-weight: bold;
        width: 40%;
    }

    /* Kaikkien taulukoiden ensimmäinen rivi (otsikot) */
    table tr:first-child th {
        background-color: #e0e0e0;
        font-weight: bold;
        text-align: center;
    }

    /* Responsiivisuus (mobiilinäytöt) */
    @media screen and (max-width: 600px) {
        table {
            width: 95%;
        }
    }

    /* Sivun alatunniste */
    footer {
        margin-top: 20px;
        font-size: 0.8em;
        text-align: center;
    }

    card {
        border: 1px solid #ccc;
        border-radius: 8px;
        padding: 1rem;
        margin-bottom: 1rem;
        }
    .card-header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        }
    .card-texts {
        /* vasen palsta teksteille */
        flex: 1;
        }
    .card-texts p {
        margin: 0.25rem 0;
        }
    .card-chart {
    /* oikea palsta kaaviolle */
    margin-left: 1rem;
    display: flex;
    align-items: center;
    }
    .details {
    margin-top: 0.5rem;
  }
</style>

    <script>
        // Funktio piilottaa/näyttää lisätiedot-kortin osion
        function toggleDetails(id, btn) {
            var element = document.getElementById(id);
            if (element.classList.contains("show")) {
                element.classList.remove("show");
                btn.textContent = "Näytä lisätiedot";
            } else {
                element.classList.add("show");
                btn.textContent = "Piilota lisätiedot";
            }
        }
    </script>


</head>
"@


# ==========================================
# KÄYDÄÄN LÄPI KAIKKI LOOGISET LEVYT
# Luodaan jokaisesta levystä HTML-kortti. Jos levyllä ei ole
# koko- tai vapaa-tilaa, ohitetaan se.
# ==========================================
$counter = 0
foreach ($disk in $logicalDisks) {
    if (-not ($disk.Size -and $disk.FreeSpace)) { continue }

    $counter++
    # $detailsId  = "details$counter"

    # Muunnokset gigatavuiksi ja prosenttilaskelmat
    $sizeGB     = [math]::Round($disk.Size / 1GB, 2)
    $freeGB     = [math]::Round($disk.FreeSpace / 1GB, 2)
    $usedGB     = [math]::Round($sizeGB - $freeGB, 2)
    $usagePct   = [math]::Round(($usedGB / $sizeGB) * 100, 1)
    $angle      = [math]::Round(360 * ($usedGB / $sizeGB), 1)
    $volumeName = if ($disk.VolumeName) { $disk.VolumeName } else { "Ei nimeä" }

    # ======================================
    # SVG-PIIRROKSESSA TARVITTAVAT LASKELMAT
    # Määritetään kaaren loppukohta ja iso-kaari-lippu
    # piirrettävälle sektori-osuudelle.
    # ======================================
    $largeArcFlag = if ($angle -gt 180) { 1 } else { 0 }
    $x = [math]::Round(18 + 16 * [math]::Sin($angle * [math]::PI / 180), 2)
    $y = [math]::Round(18 - 16 * [math]::Cos($angle * [math]::PI / 180), 2)

    # Tulostettava SVG-merkkijono
    $chartSvg = @"
<svg width='80' height='80' viewBox='0 0 36 36' class='pie'>
  <circle cx='18' cy='18' r='16' fill='#eee'/>
  <path d='M18 2 A16 16 0 $largeArcFlag 1 $x $y L18 18 Z' fill='#007bff'/>
  <text x='18' y='22' font-size='8' text-anchor='middle' fill='#333'>$usagePct`%</text>
</svg>
"@

    $html += @"

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
        <tr><th>Total Memory (GB)</th><td>$totalMemory</td></tr>
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


"@

if ($disk.DriveType -eq 4) {
        $html += @"
<div class='card'>
  <div class="card-header">
    <div class="card-texts">
  <p><strong>Levy:</strong> $($disk.DeviceID) (verkkojako)</p>
  <p><strong>Nimi:</strong> $volumeName</p>
  <p><strong>Koko:</strong> $sizeGB GB</p>
  <p><em>Fyysisiä tietoja ei saatavilla verkkojaolle.</em></p>
    </div>
       <div class="card-chart">
      $chartSvg
    </div>
    </div>
  </div>

"@
        continue
    }

    try {
        $driveLetter = $disk.DeviceID.TrimEnd(':')
        $partition   = Get-Partition -DriveLetter $driveLetter -ErrorAction Stop
        $diskNumber  = ($partition | Get-Disk).Number

        $info        = $physicalDisks[$diskNumber]
        $busType     = $info.BusType
        $mediaType   = $info.MediaType
        $model       = $info.Model
        $health      = $info.HealthStatus
        $firmware    = $info.FirmwareVersion

        # Jos mediaType on epäspesifioitu, korvataan järkevämmällä
        if (-not $mediaType -or $mediaType -eq 'Unspecified') {
            switch ($busType) {
                'SATA' { $mediaType = 'HDD' }
                'SAS'  { $mediaType = 'HDD' }
                'NVMe' { $mediaType = 'SSD (NVMe)' }
                default { $mediaType = '' }
            }
        }
        # Aseta puuttuvat malli-, terveystila- ja firmware-arvot
        foreach ($prop in 'model','health','firmware') {
            if (-not (Get-Variable $prop -Scope 0).Value) {
                Set-Variable -Name $prop -Value 'Ei saatavilla'
            }
        }
    }
    catch {
        # Jos jokin menee pieleen, merkitään kaikki puuttuviksi
        $busType   = 'Tuntematon'
        $mediaType = 'Ei saatavilla'
        $model     = 'Ei saatavilla'
        $health    = 'Ei saatavilla'
        $firmware  = 'Ei saatavilla'
    }

    $html += @"
<div class='card'>
  <div class="card-header">
    <div class="card-texts">
  <p><strong>Levy:</strong> $($disk.DeviceID)</p>
  <p><strong>Nimi:</strong> $volumeName</p>
  <p><strong>Koko:</strong> $sizeGB GB</p>
      <p><strong>Vapaa:</strong> $freeGB GB</p>
    <p><strong>Käytetty:</strong> $usedGB GB ($usagePct`%)</p>
    <p><strong>Levyn tyyppi:</strong> $busType $mediaType</p>
    <p><strong>Malli:</strong> $model</p>
    <p><strong>Terveystila:</strong> $health</p>
    <p><strong>Firmware:</strong> $firmware</p>
    </div>
    <div class="card-chart">
      $chartSvg
    </div>
</div>
</div>
"@
}

$html += @"
<footer>
    <p>&copy; 2025 Juha Hokkanen. Päivitetty: $currentDateTime</p>
</footer>
</body>
</html>
"@

# Päivitä tiedot GitHub-repositorioon
$localRepoPath = "C:\Koodit\scriptit\TotalPCInfo"

if (-not (Test-Path -Path $localRepoPath)) {
    Write-Host "Virhe: GitHub-repositoriota ei löydy polusta $localRepoPath. Tarkista polku."
    exit 1
}

# Määritä kohdekansio, käytetään "docs" kansiota
$destinationFolder = "$localRepoPath\docs"
if (-not (Test-Path -Path $destinationFolder)) {
    New-Item -Path $destinationFolder -ItemType Directory | Out-Null
    Write-Host "Luotiin kansio: $destinationFolder"
}

# Luo ja tallenna HTML-tiedosto suoraan GitHub-repositorioon (docs/index.html)
$htmlPath = "$destinationFolder\index.html"

# Kirjoita HTML-tiedosto levylle
$htmlContent | Out-File -FilePath $htmlPath -Encoding utf8
Write-Host "index.html tallennettu polkuun $htmlPath"

Set-Location -Path $localRepoPath
try {
    git add docs/index.html
    git commit -m "Päivitetty index.html kansioon 'docs' - $currentDateTime"
    git push origin main
    Write-Host "Tietokoneen tiedot päivitetty GitHubiin."
} catch {
    Write-Host "Virhe GitHub-pushin aikana: $_"
    exit 1
}

# Odota 60 sekuntia ennen kuin avaa GitHub Pages -sivun
Write-Host "Odotetaan 60 sekuntia, jotta GitHub Pages ehtii päivittyä..."
Start-Sleep -Seconds 60

#Avaa päivitetty sivu GitHub Pagesissa
# $webAppUrl = "https://juhahokkanen.github.io/pc-info-web/"
# Start-Process $webAppUrl