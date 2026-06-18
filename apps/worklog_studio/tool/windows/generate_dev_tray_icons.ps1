# Generate DEV variants of the tray icons (idle/running) by overlaying a
# small amber badge dot in the corner — a full "DEV" ribbon isn't legible at
# tray size (16-32px), so a distinct color badge is used instead.
#
# Usage (from apps/worklog_studio/):
#   pwsh tool/windows/generate_dev_tray_icons.ps1

Add-Type -AssemblyName System.Drawing

$assetsDir = Join-Path $PSScriptRoot "..\..\assets"

function Add-DevBadge {
    param([string]$SrcPath, [string]$DestPath)

    $src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $SrcPath).Path)
    $size = $src.Width

    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.DrawImage($src, 0, 0, $size, $size)

    # Badge: amber dot with a white ring, top-right corner — distinct from
    # both the idle (black) and running (red) palettes already in use.
    $badgeDiameter = [int]($size * 0.42)
    $ringDiameter = [int]($badgeDiameter * 1.25)
    $badgeLeft = $size - $ringDiameter
    $badgeTop = 0
    $ringOffset = [int](($ringDiameter - $badgeDiameter) / 2)

    $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.FillEllipse($whiteBrush, $badgeLeft, $badgeTop, $ringDiameter, $ringDiameter)

    $amberBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 160, 0))
    $g.FillEllipse(
        $amberBrush,
        $badgeLeft + $ringOffset,
        $badgeTop + $ringOffset,
        $badgeDiameter,
        $badgeDiameter
    )

    $g.Dispose()
    $src.Dispose()

    $bmp.Save($DestPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()

    Write-Host "Written: $DestPath"
}

Add-DevBadge `
    -SrcPath (Join-Path $assetsDir "app_icon_idle.png") `
    -DestPath (Join-Path $assetsDir "app_icon_idle_dev.png")

Add-DevBadge `
    -SrcPath (Join-Path $assetsDir "app_icon_running.png") `
    -DestPath (Join-Path $assetsDir "app_icon_running_dev.png")

function ConvertTo-Ico {
    param([string]$PngPath, [string]$IcoPath, [int[]]$Sizes = @(256, 48, 32, 16))

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

ConvertTo-Ico `
    -PngPath (Join-Path $assetsDir "app_icon_idle_dev.png") `
    -IcoPath (Join-Path $assetsDir "app_icon_idle_dev.ico")

ConvertTo-Ico `
    -PngPath (Join-Path $assetsDir "app_icon_running_dev.png") `
    -IcoPath (Join-Path $assetsDir "app_icon_running_dev.ico")

Write-Host "Done."
