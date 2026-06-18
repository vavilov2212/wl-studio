# Build the full DEV icon set (macOS appiconset + Windows ico) from
# assets/branding/app_icon_dev_master.png. Writes into AppIconDev.appiconset
# and app_icon_dev.ico — parallel, non-live locations swapped in by
# select_app_icon.ps1. Never touches the live AppIcon.appiconset / app_icon.ico.
#
# Usage (from apps/worklog_studio/):
#   pwsh tool/windows/generate_dev_icon_set.ps1

Add-Type -AssemblyName System.Drawing

$brandingDir   = Join-Path $PSScriptRoot "..\..\assets\branding"
$devMasterPng  = Join-Path $brandingDir "app_icon_dev_master.png"
$macIconDir    = Join-Path $PSScriptRoot "..\..\macos\Runner\Assets.xcassets"
$macProdDir    = Join-Path $macIconDir "AppIconProd.appiconset"
$macDevDir     = Join-Path $macIconDir "AppIconDev.appiconset"
$winResources  = Join-Path $PSScriptRoot "..\..\windows\runner\resources"

if (!(Test-Path $macDevDir)) { New-Item -ItemType Directory -Path $macDevDir -Force | Out-Null }

function Resize-Png {
    param([string]$SrcPath, [string]$DestPath, [int]$Size)
    $src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $SrcPath).Path)
    $resized = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($resized)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($src, 0, 0, $Size, $Size)
    $g.Dispose()
    $resized.Save($DestPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $resized.Dispose()
    $src.Dispose()
    Write-Host "Written: $DestPath"
}

function ConvertTo-Ico {
    param([string]$PngPath, [string]$IcoPath, [int[]]$Sizes = @(256, 128, 64, 48, 32, 16))

    $srcBitmap = [System.Drawing.Bitmap]::FromFile((Resolve-Path $PngPath).Path)
    $ms = New-Object System.IO.MemoryStream
    $writer = New-Object System.IO.BinaryWriter($ms)

    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$Sizes.Count)

    $imageStreams = @()
    foreach ($size in $Sizes) {
        $resized = New-Object System.Drawing.Bitmap($size, $size)
        $g = [System.Drawing.Graphics]::FromImage($resized)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($srcBitmap, 0, 0, $size, $size)
        $g.Dispose()

        $imgStream = New-Object System.IO.MemoryStream
        $resized.Save($imgStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $resized.Dispose()
        $imageStreams += $imgStream
    }

    $dirOffset = $ms.Position
    foreach ($imgStream in $imageStreams) {
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint32]$imgStream.Length)
        $writer.Write([uint32]0)
    }

    $dataOffset = [uint32]$ms.Position
    $ms.Seek($dirOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
    $patchWriter = New-Object System.IO.BinaryWriter($ms)

    for ($i = 0; $i -lt $Sizes.Count; $i++) {
        $sz = $Sizes[$i]
        $w = if ($sz -ge 256) { 0 } else { [byte]$sz }
        $h = if ($sz -ge 256) { 0 } else { [byte]$sz }
        $patchWriter.Write([byte]$w)
        $patchWriter.Write([byte]$h)
        $patchWriter.Write([byte]0)
        $patchWriter.Write([byte]0)
        $patchWriter.Write([uint16]1)
        $patchWriter.Write([uint16]32)
        $patchWriter.Write([uint32]$imageStreams[$i].Length)
        $patchWriter.Write([uint32]$dataOffset)
        $dataOffset += [uint32]$imageStreams[$i].Length
    }

    $ms.Seek(0, [System.IO.SeekOrigin]::End) | Out-Null
    foreach ($imgStream in $imageStreams) {
        $writer.Write($imgStream.ToArray())
        $imgStream.Dispose()
    }

    $srcBitmap.Dispose()
    [System.IO.File]::WriteAllBytes($IcoPath, $ms.ToArray())
    $ms.Dispose()
    Write-Host "Written: $IcoPath"
}

# macOS appiconset — same filenames/sizes as the prod set (per Contents.json)
Resize-Png -SrcPath $devMasterPng -DestPath (Join-Path $macDevDir "app_icon_16.png")   -Size 16
Resize-Png -SrcPath $devMasterPng -DestPath (Join-Path $macDevDir "app_icon_32.png")   -Size 32
Resize-Png -SrcPath $devMasterPng -DestPath (Join-Path $macDevDir "app_icon_64.png")   -Size 64
Resize-Png -SrcPath $devMasterPng -DestPath (Join-Path $macDevDir "app_icon_128.png")  -Size 128
Resize-Png -SrcPath $devMasterPng -DestPath (Join-Path $macDevDir "app_icon_256.png")  -Size 256
Resize-Png -SrcPath $devMasterPng -DestPath (Join-Path $macDevDir "app_icon_512.png")  -Size 512
Resize-Png -SrcPath $devMasterPng -DestPath (Join-Path $macDevDir "app_icon_1024.png") -Size 1024
Copy-Item (Join-Path $macProdDir "Contents.json") (Join-Path $macDevDir "Contents.json") -Force
Write-Host "Written: $(Join-Path $macDevDir 'Contents.json')"

# Windows ico
ConvertTo-Ico -PngPath $devMasterPng -IcoPath (Join-Path $winResources "app_icon_dev.ico") -Sizes @(256, 128, 64, 48, 32, 16)

Write-Host "Done."
