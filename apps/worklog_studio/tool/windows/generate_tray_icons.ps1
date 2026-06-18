# Convert PNG tray/app icons to ICO for Windows using .NET System.Drawing.
# No external tools required — works on any Windows machine with .NET.
#
# Usage (from apps/worklog_studio/):
#   pwsh tool/windows/generate_tray_icons.ps1

Add-Type -AssemblyName System.Drawing

$assetsDir = Join-Path $PSScriptRoot "..\..\assets"
$macAppIconDir = Join-Path $PSScriptRoot "..\..\macos\Runner\Assets.xcassets\AppIcon.appiconset"
$windowsResourcesDir = Join-Path $PSScriptRoot "..\..\windows\runner\resources"

function ConvertTo-Ico {
    param(
        [string]$PngPath,
        [string]$IcoPath,
        [int[]]$Sizes = @(256, 48, 32, 16)
    )

    $srcBitmap = [System.Drawing.Bitmap]::FromFile((Resolve-Path $PngPath).Path)

    $ms = New-Object System.IO.MemoryStream
    $writer = New-Object System.IO.BinaryWriter($ms)

    # ICO header
    $writer.Write([uint16]0)       # reserved
    $writer.Write([uint16]1)       # type: ICO
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

    # Directory entries (each 16 bytes): write placeholders, fix offsets after
    $dirOffset = $ms.Position
    foreach ($imgStream in $imageStreams) {
        $writer.Write([byte]0)   # width  (0 = 256)
        $writer.Write([byte]0)   # height (0 = 256)
        $writer.Write([byte]0)   # color count
        $writer.Write([byte]0)   # reserved
        $writer.Write([uint16]1) # planes
        $writer.Write([uint16]32) # bit count
        $writer.Write([uint32]$imgStream.Length)
        $writer.Write([uint32]0) # offset placeholder
    }

    # Patch width/height and offsets now that we know them
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

    # Seek to end and write image data
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

ConvertTo-Ico `
    -PngPath "$assetsDir\app_icon_idle.png" `
    -IcoPath "$assetsDir\app_icon_idle.ico"

ConvertTo-Ico `
    -PngPath "$assetsDir\app_icon_running.png" `
    -IcoPath "$assetsDir\app_icon_running.ico"

# App icon (taskbar/exe) — reuse the macOS master art so Windows matches
# the branded icon instead of Flutter's stock logo.
ConvertTo-Ico `
    -PngPath "$macAppIconDir\app_icon_1024.png" `
    -IcoPath "$windowsResourcesDir\app_icon.ico" `
    -Sizes @(256, 128, 64, 48, 32, 16)

Write-Host "Done."
