# Build script for Vaktet 2026 Windows Deliverables
# Generates:
#   1. Vaktet.exe (Portable offline executable, no install needed)
#   2. Vaktet.msi (Windows Installer package)

param(
    [switch]$SkipMsi = $false
)

$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Building Vaktet 2026 for Windows" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Prepare Staging Directory for Web Assets
Write-Host "`n[1/4] Packaging web assets into assets.zip..." -ForegroundColor Yellow
$StagingDir = Join-Path $env:TEMP "vaktet_assets_staging_$(Get-Random)"
if (Test-Path $StagingDir) { Remove-Item -Recurse -Force $StagingDir }
New-Item -ItemType Directory -Path $StagingDir | Out-Null

$CoreFiles = @("index.html", "styles.css", "app.js", "data.js", "tips.js", "sw.js", "manifest.webmanifest")
foreach ($f in $CoreFiles) {
    if (Test-Path $f) {
        Copy-Item $f -Destination $StagingDir
    } else {
        Write-Warning "File not found: $f"
    }
}

Copy-Item "icons", "fonts" -Destination $StagingDir -Recurse

$AssetsZip = Join-Path $RootDir "windows\assets.zip"
if (Test-Path $AssetsZip) { Remove-Item $AssetsZip -Force }

Compress-Archive -Path "$StagingDir\*" -DestinationPath $AssetsZip -CompressionLevel Optimal
Remove-Item -Recurse -Force $StagingDir

$ZipSize = (Get-Item $AssetsZip).Length / 1KB
Write-Host "  -> assets.zip created ($([math]::Round($ZipSize, 1)) KB)" -ForegroundColor Green

# 2. Compile Vaktet.exe with csc.exe
Write-Host "`n[2/4] Compiling Vaktet.exe (.NET Framework 4.8 / C#)..." -ForegroundColor Yellow
$CscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $CscPath)) {
    $CscPath = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
}

if (-not (Test-Path $CscPath)) {
    throw "C# compiler csc.exe not found under Microsoft.NET Framework v4.0.30319."
}

$FrameworkDir = Split-Path -Parent $CscPath
$ExeOutput = Join-Path $RootDir "windows\Vaktet.exe"
$IconPath = Join-Path $RootDir "icons\app.ico"
$SourcePath = Join-Path $RootDir "windows\Program.cs"

& $CscPath /nologo /target:winexe /optimize+ `
    "/out:$ExeOutput" `
    "/win32icon:$IconPath" `
    "/resource:$AssetsZip,assets.zip" `
    "/r:System.dll" `
    "/r:System.Core.dll" `
    "/r:System.Drawing.dll" `
    "/r:System.Windows.Forms.dll" `
    "/r:$FrameworkDir\System.IO.Compression.dll" `
    "/r:$FrameworkDir\System.IO.Compression.FileSystem.dll" `
    "$SourcePath"

if ($LASTEXITCODE -ne 0) {
    throw "csc.exe compilation failed with exit code $LASTEXITCODE."
}

$ExeSize = (Get-Item $ExeOutput).Length / 1KB
Write-Host "  -> Vaktet.exe compiled successfully ($([math]::Round($ExeSize, 1)) KB)" -ForegroundColor Green

# 3. Compile Vaktet.msi with WiX Toolset
if (-not $SkipMsi) {
    Write-Host "`n[3/4] Building Vaktet.msi (WiX Toolset)..." -ForegroundColor Yellow

    # Check for WiX tools (local tools dir, PATH, or download portable)
    $CandleExe = Get-Command "candle.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    $LightExe = Get-Command "light.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source

    if (-not $CandleExe -or -not $LightExe) {
        $LocalWix = Join-Path $RootDir "windows\tools\wix"
        if ((Test-Path "$LocalWix\candle.exe") -and (Test-Path "$LocalWix\light.exe")) {
            $CandleExe = "$LocalWix\candle.exe"
            $LightExe = "$LocalWix\light.exe"
        } else {
            Write-Host "  Downloading portable WiX 3.11 binaries..." -ForegroundColor Cyan
            New-Item -ItemType Directory -Path $LocalWix -Force | Out-Null
            $TempZip = Join-Path $env:TEMP "wix311_binaries.zip"
            curl.exe -s -L -o $TempZip "https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311-binaries.zip"
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip, $LocalWix)
            Remove-Item $TempZip -Force
            $CandleExe = "$LocalWix\candle.exe"
            $LightExe = "$LocalWix\light.exe"
        }
    }

    $WxsFile = Join-Path $RootDir "windows\Vaktet.wxs"
    $WixObjFile = Join-Path $RootDir "windows\Vaktet.wixobj"
    $MsiOutput = Join-Path $RootDir "windows\Vaktet.msi"

    & $CandleExe -nologo -out "$WixObjFile" "$WxsFile"
    if ($LASTEXITCODE -ne 0) {
        throw "WiX candle compilation failed."
    }

    & $LightExe -nologo -sval -out "$MsiOutput" "$WixObjFile"
    if ($LASTEXITCODE -ne 0) {
        throw "WiX light linking failed."
    }

    # Clean intermediate WiX object files
    if (Test-Path $WixObjFile) { Remove-Item $WixObjFile -Force }
    $WixPdb = [System.IO.Path]::ChangeExtension($MsiOutput, ".wixpdb")
    if (Test-Path $WixPdb) { Remove-Item $WixPdb -Force }

    $MsiSize = (Get-Item $MsiOutput).Length / 1KB
    Write-Host "  -> Vaktet.msi built successfully ($([math]::Round($MsiSize, 1)) KB)" -ForegroundColor Green
}

# 4. Copy deliverables to dist/
Write-Host "`n[4/4] Assembling release deliverables in dist/..." -ForegroundColor Yellow
$DistDir = Join-Path $RootDir "dist\windows"
if (-not (Test-Path $DistDir)) { New-Item -ItemType Directory -Path $DistDir -Force | Out-Null }

Copy-Item $ExeOutput -Destination $DistDir -Force
if (-not $SkipMsi) {
    Copy-Item $MsiOutput -Destination $DistDir -Force
}

Write-Host "`nSUCCESS! Generated deliverables:" -ForegroundColor Green
Get-ChildItem $DistDir | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
