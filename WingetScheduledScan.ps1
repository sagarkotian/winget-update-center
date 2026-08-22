[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'WingetCore.psm1'
Import-Module $modulePath -Force

function Show-ScanNotification {
    param(
        [Parameter(Mandatory)][string] $Title,
        [Parameter(Mandatory)][string] $Message,
        [ValidateSet('Info', 'Warning', 'Error')][string] $Kind = 'Info'
    )

    if ($Title.Length -gt 63) { $Title = $Title.Substring(0, 63) }
    if ($Message.Length -gt 255) { $Message = $Message.Substring(0, 252) + '...' }
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $notification = [System.Windows.Forms.NotifyIcon]::new()
    try {
        $notification.Icon = switch ($Kind) {
            'Warning' { [System.Drawing.SystemIcons]::Warning }
            'Error' { [System.Drawing.SystemIcons]::Error }
            default { [System.Drawing.SystemIcons]::Information }
        }
        $notification.BalloonTipIcon = switch ($Kind) {
            'Warning' { [System.Windows.Forms.ToolTipIcon]::Warning }
            'Error' { [System.Windows.Forms.ToolTipIcon]::Error }
            default { [System.Windows.Forms.ToolTipIcon]::Info }
        }
        $notification.BalloonTipTitle = $Title
        $notification.BalloonTipText = $Message
        $notification.Text = 'Winget Update Center'
        $notification.Visible = $true
        $notification.ShowBalloonTip(10000)
        Start-Sleep -Seconds 8
    }
    finally {
        $notification.Visible = $false
        $notification.Dispose()
    }
}

$snapshotPath = Join-Path (Get-WingetDataDirectory) 'last-scan.json'
try {
    $inventory = Get-WingetInventory
    $updates = @($inventory.Updates)
    [pscustomobject]@{
        Timestamp   = Get-Date -Format 'o'
        Succeeded   = $true
        UpdateCount = $updates.Count
        Updates     = @($updates | Select-Object Name, Id, InstalledVersion, AvailableVersion, Source)
        Error       = ''
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $snapshotPath -Encoding UTF8

    if ($updates.Count -gt 0) {
        $message = if ($updates.Count -eq 1) {
            "1 application update is available. Open Winget Update Center to review it."
        }
        else {
            "$($updates.Count) application updates are available. Open Winget Update Center to review them."
        }
        Show-ScanNotification -Title 'Application updates available' -Message $message -Kind Info
    }
}
catch {
    $errorMessage = $_.Exception.Message
    [pscustomobject]@{
        Timestamp   = Get-Date -Format 'o'
        Succeeded   = $false
        UpdateCount = 0
        Updates     = @()
        Error       = $errorMessage
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $snapshotPath -Encoding UTF8
    Show-ScanNotification -Title 'Winget update scan failed' -Message $errorMessage -Kind Error
    exit 1
}
