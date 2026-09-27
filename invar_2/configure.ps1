#Requires -RunAsAdministrator

$msys2Path = "C:\msys64"
if (-not (Test-Path $msys2Path)) {
    Write-Error "MSYS2 not found"
    exit 1
}

Write-Host "Installing toolchain" -ForegroundColor Yellow
$packages = @(
    "mingw-w64-ucrt-x86_64-gcc"
    "mingw-w64-ucrt-x86_64-gdb"
    "mingw-w64-ucrt-x86_64-make"
    "mingw-w64-ucrt-x86_64-cmake"
    "mingw-w64-ucrt-x86_64-ninja"
)

foreach ($pkg in $packages) {
    Write-Host "Installing $pkg" -ForegroundColor Cyan
    & "$msys2Path\usr\bin\bash.exe" -lc "pacman -S --noconfirm $pkg"
}

$ucrtPath = "$msys2Path\ucrt64\bin"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$ucrtPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$ucrtPath", "Machine")
    Write-Host "UCRT64 added to system PATH." -ForegroundColor Green
}

Write-Host "MSYS2 UCRT64 setup complete" -ForegroundColor Green
