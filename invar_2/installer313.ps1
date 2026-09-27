#Requires -RunAsAdministrator

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR"   { "Red" }
        "WARN"    { "Yellow" }
        "SUCCESS" { "Green" }
        default   { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Install-FromGoogleDrive {
    param(
        [string]$FileId,
        [string]$FileName,
        [string]$SilentArgs,
        [string]$DisplayName
    )
    
    Write-Log "Installing $DisplayName (from Google Drive)..." "INFO"
    $tempPath = Join-Path $env:TEMP $FileName
    $tempHtml = Join-Path $env:TEMP "gdrive_page.html"
    
    try {
        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        
        $initialUrl = "https://drive.google.com/uc?export=download&id=$FileId"
        Write-Log "Step 1: Requesting confirmation page..." "INFO"
        
        Invoke-WebRequest -Uri $initialUrl -OutFile $tempHtml -WebSession $session -UseBasicParsing
        
        $htmlContent = Get-Content $tempHtml -Raw
        $uuidValue = $null
        
        if ($htmlContent -match 'name="uuid" value="([^"]+)"') {
            $uuidValue = $matches[1]
            Write-Log "Found uuid token: $uuidValue" "INFO"
        }
        elseif ($htmlContent -match 'confirm=([0-9A-Za-z_]+)') {
            $uuidValue = $matches[1]
            Write-Log "Found confirm token: $uuidValue" "INFO"
        }

        if (-not $uuidValue) {
            Write-Log "No confirmation token found. Trying direct download as fallback..." "WARN"
            Copy-Item $tempHtml $tempPath -Force
        } else {
            Write-Log "Step 2: Downloading actual file with token..." "INFO"
            $downloadUrl = "https://drive.google.com/uc?export=download&confirm=t&uuid=$uuidValue&id=$FileId"
            
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath -WebSession $session -UseBasicParsing
        }
        
        Remove-Item $tempHtml -Force -ErrorAction SilentlyContinue

        if (Test-Path $tempPath) {
            $bytes = [System.IO.File]::ReadAllBytes($tempPath) | Select-Object -First 2
            if ($bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
                Write-Log "$DisplayName - downloaded file is not an EXE. Likely another HTML page." "ERROR"
                Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
                return
            }
        } else {
            Write-Log "$DisplayName - download failed, file not found." "ERROR"
            return
        }

        Write-Log "Starting $DisplayName installation..." "INFO"
        $result = Start-Process -FilePath $tempPath -ArgumentList $SilentArgs `
            -Wait -NoNewWindow -PassThru
        
        Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        
        if ($result.ExitCode -eq 0) {
            Write-Log "$DisplayName installed successfully." "SUCCESS"
        } else {
            Write-Log "$DisplayName - error (code $($result.ExitCode))." "ERROR"
        }
        
    } catch {
        Write-Log "Failed to download/install $DisplayName : $_" "ERROR"
        Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        Remove-Item $tempHtml -Force -ErrorAction SilentlyContinue
    }
}

Install-FromGoogleDrive -FileId "1ygbqxneypuixRfrObqT53raBlCUb6Kxz" `
    -FileName "ramus-setup.exe" `
    -SilentArgs "/S" `
    -DisplayName "Ramus Educational"

Install-FromGoogleDrive -FileId "1sP0ZvSIlDDYx-RYqluLbVIfr1Vy3Qvzk" `
    -FileName "aris-express-setup.exe" `
    -SilentArgs "/VERYSILENT /NORESTART" `
    -DisplayName "ARIS EXPRESS"

$result = Start-Process -FilePath "choco" `
    -ArgumentList "install archi -y --no-progress" `
    -Wait -NoNewWindow -PassThru
if ($result.ExitCode -eq 0) {
    Write-Log "Archi installed successfully." "SUCCESS"
} else {
    Write-Log "Archi - error (code $($result.ExitCode))." "ERROR"
}

Write-Host "Installation complete" -ForegroundColor Green
