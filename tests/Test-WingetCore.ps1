$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WingetCore.psm1'
$testDataPath = Join-Path ([IO.Path]::GetTempPath()) ('WingetUpdateCenter-Test-{0}' -f [guid]::NewGuid().ToString('N'))
$previousDataPath = [Environment]::GetEnvironmentVariable('WINGET_UPDATE_CENTER_DATA')
[Environment]::SetEnvironmentVariable('WINGET_UPDATE_CENTER_DATA', $testDataPath)

try {
    Import-Module $modulePath -Force

    $empty = @(ConvertFrom-WingetTable -Lines '' -TableKind Upgrade)
    if ($empty.Count -ne 0) { throw 'Empty Winget output should produce an empty result.' }

    $table = @(
        'Name               Id                     Version  Available  Source',
        '-------------------------------------------------------------------',
        'Microsoft Edge     Microsoft.Edge         130.0.1  131.0.1    winget'
    )
    $packages = @(ConvertFrom-WingetTable -Lines $table -TableKind Upgrade)
    if ($packages.Count -ne 1 -or $packages[0].AvailableVersion -ne '131.0.1') {
        throw 'Winget upgrade table parsing failed.'
    }

    Add-WingetHistoryRecord -Record ([pscustomobject]@{
        Timestamp = '2026-08-22T12:00:00.0000000+00:00'; Name = 'Microsoft Edge'; Id = 'Microsoft.Edge'
        InstalledVersion = '130.0.1'; TargetVersion = '131.0.1'; Result = 'Succeeded'; ExitCode = 0; LogFile = ''
    })
    Add-WingetHistoryRecord -Record ([pscustomobject]@{
        Timestamp = '2026-08-22T13:00:00.0000000+00:00'; Name = 'Contoso App'; Id = 'Contoso.App'
        InstalledVersion = '1.0'; TargetVersion = '2.0'; Result = 'Failed'; ExitCode = 1; LogFile = 'example.log'
    })
    $history = @(Get-WingetHistory)
    if ($history.Count -ne 2 -or $history[0].Id -ne 'Contoso.App') { throw 'History persistence or sorting failed.' }

    $failureLog = Write-WingetFailureLog -PackageId 'Contoso.App' -ExitCode 1 -Command 'winget upgrade' -Message 'Test failure'
    if (-not (Test-Path -LiteralPath $failureLog) -or (Get-Content -LiteralPath $failureLog -Raw) -notmatch 'Test failure') {
        throw 'Failure logging failed.'
    }

    Clear-WingetHistory
    if (@(Get-WingetHistory).Count -ne 0) { throw 'History clearing failed.' }

    $schedule = Get-WingetSchedule
    if ($schedule.Frequency -ne 'Disabled') { throw 'The default schedule should be disabled.' }

    Write-Output 'All WingetCore tests passed.'
}
finally {
    [Environment]::SetEnvironmentVariable('WINGET_UPDATE_CENTER_DATA', $previousDataPath)
    if ($testDataPath.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $testDataPath)) {
        Remove-Item -LiteralPath $testDataPath -Recurse -Force
    }
}
