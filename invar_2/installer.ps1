#Requires -RunAsAdministrator

# ----- HELPERS -----

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

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Chocolatey {
    Write-Log "Checking Chocolatey installation" "INFO"
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Log "Chocolatey already installed" "SUCCESS"
        return
    }
    Write-Log "Installing Chocolatey" "INFO"
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = (
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    )
    iex ((New-Object System.Net.WebClient).DownloadString(
        'https://community.chocolatey.org/install.ps1'))
    $env:Path = (
        [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [System.Environment]::GetEnvironmentVariable("Path", "User")
    )
    Write-Log "Chocolatey successfully installed" "SUCCESS"
}

function Install-ChocoPackage {
    param(
        [string]$PackageName,
        [string]$DisplayName = $PackageName,
        [string]$ExtraParams = ""
    )
    Write-Log "Installing $DisplayName ($PackageName)" "INFO"
    $chocoArgs = "install $PackageName -y --no-progress --ignore-checksums"
	if ($ExtraParams) { $chocoArgs += " $ExtraParams" }
	$result = Start-Process -FilePath "choco" -ArgumentList $chocoArgs `
		-Wait -NoNewWindow -PassThru
    if ($result.ExitCode -eq 0) {
        Write-Log "$DisplayName successfully installed." "SUCCESS"
    } else {
        Write-Log "$DisplayName - error (code $($result.ExitCode))." "ERROR"
    }
}

function Install-WingetPackage {
    param([string]$PackageId, [string]$DisplayName = $PackageId)
    Write-Log "Installing $DisplayName (winget)" "INFO"
    $result = Start-Process -FilePath "winget" `
        -ArgumentList "install --id $PackageId -e --source winget --silent --accept-package-agreements --accept-source-agreements" `
        -Wait -NoNewWindow -PassThru
    if ($result.ExitCode -eq 0) {
        Write-Log "$DisplayName successfully installed" "SUCCESS"
    } else {
        Write-Log "$DisplayName - error (code $($result.ExitCode))." "ERROR"
    }
}

function Install-FromUrl {
    param(
        [string]$Url,
        [string]$FileName,
        [string]$SilentArgs,
        [string]$DisplayName
    )
    Write-Log "Installing $DisplayName..." "INFO"
    $tempPath = Join-Path $env:TEMP $FileName
    try {
        Invoke-WebRequest -Uri $Url -OutFile $tempPath -UseBasicParsing
        Write-Log "Starting $DisplayName installation" "INFO"
        $result = Start-Process -FilePath $tempPath -ArgumentList $SilentArgs `
            -Wait -NoNewWindow -PassThru
        Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        if ($result.ExitCode -eq 0) {
            Write-Log "$DisplayName installed successfully" "SUCCESS"
        } else {
            Write-Log "$DisplayName - error (code $($result.ExitCode))." "ERROR"
        }
    } catch {
        Write-Log "Failed to download $DisplayName : $_" "ERROR"
    }
}

function Install-FromMsi {
    param(
        [string]$Url,
        [string]$FileName,
        [string]$MsiArgs,
        [string]$DisplayName
    )
    Write-Log "Installing $DisplayName (MSI)..." "INFO"
    $tempPath = Join-Path $env:TEMP $FileName
    try {
        Invoke-WebRequest -Uri $Url -OutFile $tempPath -UseBasicParsing -MaximumRedirection 10

        $sig = [System.IO.File]::ReadAllBytes($tempPath) | Select-Object -First 4
        if ($sig[0] -ne 0xD0 -or $sig[1] -ne 0xCF -or $sig[2] -ne 0x11 -or $sig[3] -ne 0xE0) {
            $size = (Get-Item $tempPath).Length
            Write-Log "$DisplayName - downloaded file is not an MSI (size=$size bytes)" "ERROR"
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
            return
        }

        Write-Log "Running msiexec for $DisplayName..." "INFO"
        $result = Start-Process -FilePath "msiexec.exe" `
            -ArgumentList "/i `"$tempPath`" $MsiArgs" `
            -Wait -NoNewWindow -PassThru

        Remove-Item $tempPath -Force -ErrorAction SilentlyContinue

        if ($result.ExitCode -eq 0 -or $result.ExitCode -eq 3010) {
            Write-Log "$DisplayName installed successfully (exit $($result.ExitCode))." "SUCCESS"
        } else {
            Write-Log "$DisplayName - error (code $($result.ExitCode))." "ERROR"
        }
    } catch {
        Write-Log "Failed to install $DisplayName : $_" "ERROR"
    }
}

# ----- CHOCOLATEY -----

if (-not (Test-Admin)) {
    Write-Log "Admin rights required" "ERROR"
    exit 1
}

Write-Log "--- Installing components through Chocolatey ---" "INFO"
Install-Chocolatey

Install-ChocoPackage -PackageName "git" -DisplayName "Git"
Install-ChocoPackage -PackageName "github-desktop" -DisplayName "GitHub Desktop"
Install-ChocoPackage -PackageName "vscode" -DisplayName "Visual Studio Code"
Install-ChocoPackage -PackageName "docker-desktop" -DisplayName "Docker Desktop"
Install-ChocoPackage -PackageName "pycharm-community" -DisplayName "PyCharm Community Edition"
Install-ChocoPackage -PackageName "python" -DisplayName "Python"
Install-ChocoPackage -PackageName "julia" -DisplayName "Julia"
Install-ChocoPackage -PackageName "rust" -DisplayName "Rust"
Install-ChocoPackage -PackageName "msys2" -DisplayName "MSYS2"
Install-ChocoPackage -PackageName "maxima" -DisplayName "Maxima"
Install-ChocoPackage -PackageName "knime" -DisplayName "KNIME Analytics Platform"
Install-ChocoPackage -PackageName "anaconda3" -DisplayName "Anaconda"
Install-ChocoPackage -PackageName "gimp" -DisplayName "GIMP"
Install-ChocoPackage -PackageName "zettlr" -DisplayName "Zettlr"
Install-ChocoPackage -PackageName "miktex" -DisplayName "MiKTeX"
Install-ChocoPackage -PackageName "texstudio" -DisplayName "TeXstudio"
Install-ChocoPackage -PackageName "far" -DisplayName "Far Manager"
Install-ChocoPackage -PackageName "sumatrapdf" -DisplayName "SumatraPDF"
Install-ChocoPackage -PackageName "flameshot" -DisplayName "Flameshot"
Install-ChocoPackage -PackageName "qalculate" -DisplayName "Qalculate!"
Install-ChocoPackage -PackageName "7zip" -DisplayName "7Zip"
Install-ChocoPackage -PackageName "googlechrome" -DisplayName "Google Chrome"
Install-ChocoPackage -PackageName "firefox" -DisplayName "Mozilla Firefox"
Install-ChocoPackage -PackageName "microsoft-edge" -DisplayName "Microsoft Edge"

# --- WINGET/DIRECT ---

Write-Log "--- Installing other components ---" "INFO"

Install-WingetPackage -PackageId "TheBrowserCompany.Arc" -DisplayName "Arc Browser"

Install-FromUrl -Url "https://browser.yandex.ru/download/?os=win" `
    -FileName "YandexBrowserSetup.exe" `
    -SilentArgs "--silent --do-not-launch-browser" `
    -DisplayName "Yandex Browser"

Install-FromMsi `
    -Url "https://webdav.yandex.ru/share/dist/YTelemostSetup.msi" `
    -FileName "YTelemostSetup.msi" `
    -MsiArgs '/qn ALLUSERS="1" MSIINSTALLPERUSER="" SKIP_LAUNCH=1 NODESKTOPSHORTCUT=1' `
    -DisplayName "Yandex Telemost"

Install-FromUrl -Url "https://dl.salutejazz.ru/desktop/latest/jazz.exe" `
    -FileName "jazz.exe" `
    -SilentArgs "/silent" `
    -DisplayName "Sber Jazz"

# --- WSL2 ---

Write-Log "--- WSL2 setup ---" "INFO"

dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
wsl --install --no-distribution
wsl --install -d Ubuntu-22.04 --no-launch
wsl --install -d Ubuntu-24.04 --no-launch
Write-Log "WSL 2 setup complete, reboot recommended" "WARN"

# --- VSCODE ---

Write-Log "--- Installing VSCode extensions ---" "INFO"

$vscodeExtensions = @(
    "ms-python.python"
    "ms-python.vscode-pylance"
    "ms-python.debugpy"
    "ms-vscode.cpptools"
    "ms-azuretools.vscode-docker"
    "ecmel.vscode-html-css"
    "dbaeumer.vscode-eslint"
    "esbenp.prettier-vscode"
    "ritwickdey.LiveServer"
    "eamodio.gitlens"
    "GitHub.vscode-pull-request-github"
    "julialang.language-julia"
    "rust-lang.rust-analyzer"
    "James-Yu.latex-workshop"
    "ms-vscode-remote.remote-wsl"
    "streetsidesoftware.code-spell-checker"
    "yzhang.markdown-all-in-one"
    "redhat.vscode-yaml"
)

$env:Path = (
    [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
    [System.Environment]::GetEnvironmentVariable("Path", "User")
)

foreach ($ext in $vscodeExtensions) {
    Write-Log "Installing extension: $ext" "INFO"
    Start-Process -FilePath "code" -ArgumentList "--install-extension $ext --force" `
        -Wait -NoNewWindow
}

Write-Log "Installation complete, reboot recommended" "SUCCESS"
