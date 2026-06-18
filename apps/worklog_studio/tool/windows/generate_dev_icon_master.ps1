# Generate the DEV master icon (1024x1024) by overlaying a red "DEV" ribbon
# on top of the production master art. Source of truth for both platforms'
# dev icon variants — re-run this after the prod master art changes.
#
# Usage (from apps/worklog_studio/):
#   pwsh tool/windows/generate_dev_icon_master.ps1

Add-Type -AssemblyName System.Drawing

$brandingDir = Join-Path $PSScriptRoot "..\..\assets\branding"
$prodMaster  = Join-Path $brandingDir "app_icon_prod_master.png"
$devMaster   = Join-Path $brandingDir "app_icon_dev_master.png"

$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $prodMaster).Path)
$size = $src.Width

$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.DrawImage($src, 0, 0, $size, $size)

# Ribbon band: a solid red stripe across the icon, kept clear of the rounded
# corners so it reads as a clean overlay at every size, even 16px (a red
# band remains a visible color cue when the "DEV" text is no longer legible).
$bandHeight = [int]($size * 0.22)
$bandTop    = [int]($size * 0.62)
$redBrush   = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 211, 47, 47))
$g.FillRectangle($redBrush, 0, $bandTop, $size, $bandHeight)

$fontSize = [int]($bandHeight * 0.62)
$font = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$format = New-Object System.Drawing.StringFormat
$format.Alignment = [System.Drawing.StringAlignment]::Center
$format.LineAlignment = [System.Drawing.StringAlignment]::Center
$textRect = New-Object System.Drawing.RectangleF(0, $bandTop, $size, $bandHeight)
$g.DrawString("DEV", $font, $whiteBrush, $textRect, $format)

$g.Dispose()
$src.Dispose()

$bmp.Save($devMaster, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "Written: $devMaster"
