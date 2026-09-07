param(
    [string] $OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'WingetUpdateCenter.CommandPalette\Assets')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    $null = New-Item -ItemType Directory -Path $OutputDirectory -Force
}

function New-UpdateIcon {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][int] $Width,
        [Parameter(Mandatory)][int] $Height,
        [switch] $Wide
    )

    $bitmap = [Drawing.Bitmap]::new($Width, $Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.Clear([Drawing.Color]::FromArgb(0, 0, 0, 0))

        $side = [Math]::Min($Width, $Height)
        $iconSize = [int]($side * 0.78)
        $left = if ($Wide) { [int](($Width - $iconSize) / 2) } else { [int](($Width - $iconSize) / 2) }
        $top = [int](($Height - $iconSize) / 2)
        $radius = [Math]::Max(2, [int]($iconSize * 0.19))

        $pathShape = [Drawing.Drawing2D.GraphicsPath]::new()
        try {
            $diameter = $radius * 2
            $pathShape.AddArc($left, $top, $diameter, $diameter, 180, 90)
            $pathShape.AddArc($left + $iconSize - $diameter, $top, $diameter, $diameter, 270, 90)
            $pathShape.AddArc($left + $iconSize - $diameter, $top + $iconSize - $diameter, $diameter, $diameter, 0, 90)
            $pathShape.AddArc($left, $top + $iconSize - $diameter, $diameter, $diameter, 90, 90)
            $pathShape.CloseFigure()

            $background = [Drawing.Drawing2D.LinearGradientBrush]::new(
                [Drawing.Point]::new($left, $top),
                [Drawing.Point]::new($left + $iconSize, $top + $iconSize),
                [Drawing.Color]::FromArgb(255, 0, 120, 212),
                [Drawing.Color]::FromArgb(255, 72, 70, 181))
            try { $graphics.FillPath($background, $pathShape) }
            finally { $background.Dispose() }
        }
        finally { $pathShape.Dispose() }

        $white = [Drawing.Pen]::new([Drawing.Color]::White, [Math]::Max(2, $iconSize * 0.075))
        $white.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $white.EndCap = [Drawing.Drawing2D.LineCap]::Round
        try {
            $centerX = $left + ($iconSize / 2)
            $arrowTop = $top + ($iconSize * 0.22)
            $arrowBottom = $top + ($iconSize * 0.62)
            $graphics.DrawLine($white, $centerX, $arrowTop, $centerX, $arrowBottom)
            $graphics.DrawLine($white, $centerX, $arrowBottom, $left + ($iconSize * 0.33), $top + ($iconSize * 0.47))
            $graphics.DrawLine($white, $centerX, $arrowBottom, $left + ($iconSize * 0.67), $top + ($iconSize * 0.47))
            $graphics.DrawLine($white, $left + ($iconSize * 0.28), $top + ($iconSize * 0.76), $left + ($iconSize * 0.72), $top + ($iconSize * 0.76))
        }
        finally { $white.Dispose() }

        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

$assets = @(
    @{ Name = 'StoreLogo.png'; Width = 50; Height = 50 }
    @{ Name = 'Square44x44Logo.scale-200.png'; Width = 88; Height = 88 }
    @{ Name = 'Square44x44Logo.targetsize-24_altform-unplated.png'; Width = 24; Height = 24 }
    @{ Name = 'Square150x150Logo.scale-200.png'; Width = 300; Height = 300 }
    @{ Name = 'Wide310x150Logo.scale-200.png'; Width = 620; Height = 300; Wide = $true }
    @{ Name = 'SplashScreen.scale-200.png'; Width = 1240; Height = 600; Wide = $true }
    @{ Name = 'LockScreenLogo.scale-200.png'; Width = 48; Height = 48 }
)

foreach ($asset in $assets) {
    $parameters = @{
        Path = Join-Path $OutputDirectory $asset.Name
        Width = $asset.Width
        Height = $asset.Height
    }
    if ($asset.Wide) { $parameters.Wide = $true }
    New-UpdateIcon @parameters
}
