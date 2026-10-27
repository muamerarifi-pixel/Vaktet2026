# Build script for 100% Native Windows Flutter App & MSI Installer
param(
    [string]$FlutterReleaseDir = ""
)

$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Packaging Native Flutter Windows App" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

if ([string]::IsNullOrEmpty($FlutterReleaseDir)) {
    $FlutterReleaseDir = Join-Path $RootDir "flutter_app\build\windows\x64\runner\Release"
}

if (-not (Test-Path "$FlutterReleaseDir\vaktet.exe")) {
    throw "Flutter Windows release output not found at: $FlutterReleaseDir. Run 'flutter build windows --release' first."
}

$DistDir = Join-Path $RootDir "dist\windows"
if (-not (Test-Path $DistDir)) { New-Item -ItemType Directory -Path $DistDir -Force | Out-Null }

# 1. Create Portable ZIP
Write-Host "`n[1/3] Creating Vaktet-Windows-Portable.zip..." -ForegroundColor Yellow
$PortableZip = Join-Path $DistDir "Vaktet-Windows-Portable.zip"
if (Test-Path $PortableZip) { Remove-Item $PortableZip -Force }

Compress-Archive -Path "$FlutterReleaseDir\*" -DestinationPath $PortableZip -CompressionLevel Optimal
$ZipSize = (Get-Item $PortableZip).Length / 1MB
Write-Host "  -> Vaktet-Windows-Portable.zip created ($([math]::Round($ZipSize, 2)) MB)" -ForegroundColor Green

# 2. Check for WiX tools (heat, candle, light)
Write-Host "`n[2/3] Checking WiX Toolset..." -ForegroundColor Yellow
$CandleExe = Get-Command "candle.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
$LightExe = Get-Command "light.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
$HeatExe = Get-Command "heat.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source

$LocalWix = Join-Path $RootDir "windows\tools\wix"
if ((-not $CandleExe -or -not $LightExe -or -not $HeatExe) -and ((Test-Path "$LocalWix\candle.exe") -and (Test-Path "$LocalWix\heat.exe"))) {
    $CandleExe = "$LocalWix\candle.exe"
    $LightExe = "$LocalWix\light.exe"
    $HeatExe = "$LocalWix\heat.exe"
}

if (-not $CandleExe -or -not $LightExe -or -not $HeatExe) {
    Write-Host "  Downloading portable WiX 3.11 binaries..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $LocalWix -Force | Out-Null
    $TempZip = Join-Path $env:TEMP "wix311_binaries.zip"
    curl.exe -s -L -o $TempZip "https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311-binaries.zip"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip, $LocalWix)
    Remove-Item $TempZip -Force
    $CandleExe = "$LocalWix\candle.exe"
    $LightExe = "$LocalWix\light.exe"
    $HeatExe = "$LocalWix\heat.exe"
}

# 3. Harvest Release components and compile MSI
Write-Host "`n[3/3] Compiling Native Vaktet.msi with WiX..." -ForegroundColor Yellow
$AppComponentsWxs = Join-Path $RootDir "windows\AppComponents.wxs"
$WxsFile = Join-Path $RootDir "windows\Vaktet.wxs"
$MsiOutput = Join-Path $DistDir "Vaktet.msi"

& $HeatExe dir "$FlutterReleaseDir" `
    -cg AppComponents `
    -dr INSTALLFOLDER `
    -scom -sfrag -srd -sreg -gg `
    -var var.SourceDir `
    -out "$AppComponentsWxs"

if ($LASTEXITCODE -ne 0) {
    throw "heat.exe failed to harvest directory."
}

$WixObj1 = Join-Path $RootDir "windows\Vaktet.wixobj"
$WixObj2 = Join-Path $RootDir "windows\AppComponents.wixobj"

& $CandleExe -nologo "-dSourceDir=$FlutterReleaseDir" -out "$WixObj1" "$WxsFile"
& $CandleExe -nologo "-dSourceDir=$FlutterReleaseDir" -out "$WixObj2" "$AppComponentsWxs"

& $LightExe -nologo -sval -out "$MsiOutput" "$WixObj1" "$WixObj2"

# Clean intermediate files
Remove-Item "$WixObj1", "$WixObj2", "$AppComponentsWxs" -Force -ErrorAction SilentlyContinue
$WixPdb = [System.IO.Path]::ChangeExtension($MsiOutput, ".wixpdb")
if (Test-Path $WixPdb) { Remove-Item $WixPdb -Force }

$MsiSize = (Get-Item $MsiOutput).Length / 1MB
Write-Host "  -> Vaktet.msi built successfully ($([math]::Round($MsiSize, 2)) MB)" -ForegroundColor Green

Write-Host "`nSUCCESS! 100% Native Windows deliverables generated:" -ForegroundColor Green
Get-ChildItem $DistDir | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
