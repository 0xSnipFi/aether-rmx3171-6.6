param(
    [string]$SourceVendorExtracted = "..\..\narzo30A-stock\vendor_extracted",
    [string]$Destination = "..\vendor\realme\RMX3171\proprietary"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Resolve-Path (Join-Path $scriptDir $SourceVendorExtracted)
$dst = Join-Path $scriptDir $Destination

New-Item -ItemType Directory -Force -Path $dst | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dst "vendor") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dst "odm") | Out-Null

$exclude = @(
    "odm",
    "lost+found",
    "build.prop",
    "default.prop",
    "euclid_build.prop",
    "recovery-from-boot.p",
    "ro.prop",
    "rw.prop",
    "ueventd.rc",
    "data"
)
Get-ChildItem $src -Force | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $dst "vendor") -Recurse -Force
}

$odmSrc = Join-Path $src "odm"
if (Test-Path $odmSrc) {
    Copy-Item (Join-Path $odmSrc "*") (Join-Path $dst "odm") -Recurse -Force
}

$deviceOwnedVendorFiles = @(
    "vendor\etc\fstab.mt6768",
    "vendor\etc\init\hw\init.connectivity.rc",
    "vendor\etc\init\hw\init.modem.rc",
    "vendor\etc\init\hw\init.mt6768.rc",
    "vendor\etc\init\hw\init.mt6768.usb.rc",
    "vendor\etc\init\hw\init.sensor_1_0.rc"
)

foreach ($relative in $deviceOwnedVendorFiles) {
    $candidate = Join-Path $dst $relative
    if (Test-Path $candidate) {
        Remove-Item -LiteralPath $candidate -Force
    }
}

Write-Host "Staged RMX3171 proprietary blobs into $dst"
Write-Host "Vendor source: $src"
