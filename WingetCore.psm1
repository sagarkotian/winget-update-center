Set-StrictMode -Version Latest

function Remove-WingetControlSequences {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string] $Text
    )

    if ($null -eq $Text) { return '' }

    # Winget can emit ANSI colour/progress sequences even when output is redirected.
    $clean = $Text -replace "`e\[[0-?]*[ -/]*[@-~]", ''
    $clean = $clean -replace '[\u0000-\u0008\u000B\u000C\u000E-\u001F]', ''
    return $clean
}

function ConvertFrom-WingetTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]] $Lines,

        [ValidateSet('Installed', 'Upgrade')]
        [string] $TableKind = 'Installed'
    )

    $normalized = @(
        foreach ($line in $Lines) {
            (Remove-WingetControlSequences -Text $line).TrimEnd()
        }
    )

    # The row made of dashes is stable across Winget display languages. The line
    # immediately before it gives us the dynamic starting position of each column.
    $separatorIndex = -1
    for ($i = 1; $i -lt $normalized.Count; $i++) {
        if ($normalized[$i] -match '^\s*-{3,}(?:\s+-{2,})*\s*$') {
            $candidateHeader = $normalized[$i - 1]
            $headerFields = [regex]::Matches($candidateHeader, '\S(?:.*?\S)?(?=\s{2,}|$)')
            if ($headerFields.Count -ge 3) {
                $separatorIndex = $i
                break
            }
        }
    }

    if ($separatorIndex -lt 0) { return @() }

    $header = $normalized[$separatorIndex - 1]
    $headerMatches = [regex]::Matches($header, '\S(?:.*?\S)?(?=\s{2,}|$)')
    $starts = @($headerMatches | ForEach-Object { $_.Index })

    if ($starts.Count -lt 3) { return @() }

    $items = [System.Collections.Generic.List[object]]::new()
    for ($lineIndex = $separatorIndex + 1; $lineIndex -lt $normalized.Count; $lineIndex++) {
        $line = $normalized[$lineIndex]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # Ignore Winget summaries such as "5 upgrades available." and progress rows.
        if ($line -match '^\s*[-\\|/]\s*$') { continue }

        $values = [System.Collections.Generic.List[string]]::new()
        for ($column = 0; $column -lt $starts.Count; $column++) {
            $start = $starts[$column]
            if ($start -ge $line.Length) {
                $values.Add('')
                continue
            }

            $length = if ($column -lt ($starts.Count - 1)) {
                [Math]::Min($starts[$column + 1] - $start, $line.Length - $start)
            }
            else {
                $line.Length - $start
            }
            $values.Add($line.Substring($start, $length).Trim())
        }

        if ($values.Count -lt 3 -or [string]::IsNullOrWhiteSpace($values[1])) { continue }

        $available = ''
        $source = ''
        if ($values.Count -ge 5) {
            $available = $values[3]
            $source = $values[4]
        }
        elseif ($values.Count -eq 4) {
            if ($TableKind -eq 'Upgrade') { $available = $values[3] }
            else { $source = $values[3] }
        }

        $items.Add([pscustomobject]@{
            Name             = $values[0]
            Id               = $values[1]
            InstalledVersion = $values[2]
            AvailableVersion = $available
            Source           = $source
        })
    }

    return @($items)
}

function Join-ProcessArguments {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]] $Arguments)

    return (($Arguments | ForEach-Object {
        if ($_ -notmatch '[\s"]') { $_ }
        else { '"{0}"' -f ($_ -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') }
    }) -join ' ')
}

function Invoke-WingetCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]] $Arguments
    )

    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $command) {
        throw 'Winget was not found. Install or update "App Installer" from the Microsoft Store, then try again.'
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $command.Source
    $startInfo.Arguments = Join-ProcessArguments -Arguments $Arguments
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    try {
        $utf8 = [System.Text.UTF8Encoding]::new($false)
        $startInfo.StandardOutputEncoding = $utf8
        $startInfo.StandardErrorEncoding = $utf8
    }
    catch {
        # Encoding setters are unavailable on some older .NET Framework builds.
        Write-Verbose "UTF-8 process stream encoding is unavailable: $($_.Exception.Message)"
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw 'Winget could not be started.' }

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = $process.ExitCode
    $process.Dispose()

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = Remove-WingetControlSequences -Text $stdout
        Error    = Remove-WingetControlSequences -Text $stderr
        Command  = 'winget {0}' -f (Join-ProcessArguments -Arguments $Arguments)
    }
}

function Get-WingetInventory {
    [CmdletBinding()]
    param()

    $common = @('--accept-source-agreements', '--disable-interactivity')
    $installedResult = Invoke-WingetCommand -Arguments (@('list') + $common)
    if ($installedResult.ExitCode -ne 0 -and [string]::IsNullOrWhiteSpace($installedResult.Output)) {
        throw "Winget could not read installed applications. $($installedResult.Error)"
    }

    $upgradeResult = Invoke-WingetCommand -Arguments (@('list', '--upgrade-available', '--include-unknown') + $common)
    # Winget commonly uses a non-zero informational exit code when no update exists.
    $installed = @(ConvertFrom-WingetTable -Lines ($installedResult.Output -split "`r?`n") -TableKind Installed)
    $upgrades = @(ConvertFrom-WingetTable -Lines ($upgradeResult.Output -split "`r?`n") -TableKind Upgrade)

    return [pscustomobject]@{
        Installed = $installed
        Updates   = $upgrades
        CheckedAt = Get-Date
        Winget    = (& $((Get-Command winget.exe).Source) --version 2>$null | Select-Object -First 1)
    }
}

function Invoke-WingetUpgrade {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Id,
        [switch] $Silent
    )

    $arguments = @(
        'upgrade', '--id', $Id, '--exact',
        '--accept-package-agreements', '--accept-source-agreements',
        '--disable-interactivity'
    )
    if ($Silent) { $arguments += '--silent' }
    $result = Invoke-WingetCommand -Arguments $arguments

    return [pscustomobject]@{
        Id        = $Id
        Succeeded = ($result.ExitCode -eq 0)
        ExitCode  = $result.ExitCode
        Message   = (($result.Output, $result.Error) -join "`n").Trim()
        Command   = $result.Command
    }
}

function Invoke-WingetUpgradeAll {
    [CmdletBinding()]
    param([switch] $Silent)

    $arguments = @(
        'upgrade', '--all', '--include-unknown',
        '--accept-package-agreements', '--accept-source-agreements',
        '--disable-interactivity'
    )
    if ($Silent) { $arguments += '--silent' }
    $result = Invoke-WingetCommand -Arguments $arguments

    return [pscustomobject]@{
        Id        = 'All applications'
        Succeeded = ($result.ExitCode -eq 0)
        ExitCode  = $result.ExitCode
        Message   = (($result.Output, $result.Error) -join "`n").Trim()
        Command   = $result.Command
    }
}

function Get-WingetDataDirectory {
    [CmdletBinding()]
    param()

    $override = [Environment]::GetEnvironmentVariable('WINGET_UPDATE_CENTER_DATA')
    $path = if ([string]::IsNullOrWhiteSpace($override)) {
        Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'WingetUpdateCenter'
    }
    else {
        $override
    }
    if (-not (Test-Path -LiteralPath $path)) {
        $null = New-Item -ItemType Directory -Path $path -Force
    }
    return $path
}

function Get-WingetLogDirectory {
    [CmdletBinding()]
    param()

    $path = Join-Path (Get-WingetDataDirectory) 'Logs'
    if (-not (Test-Path -LiteralPath $path)) {
        $null = New-Item -ItemType Directory -Path $path -Force
    }
    return $path
}

function Get-WingetHistory {
    [CmdletBinding()]
    param()

    $path = Join-Path (Get-WingetDataDirectory) 'update-history.jsonl'
    if (-not (Test-Path -LiteralPath $path)) { return @() }

    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($line in @(Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $records.Add(($line | ConvertFrom-Json -ErrorAction Stop)) }
        catch { continue }
    }
    return @($records | Sort-Object Timestamp -Descending)
}

function Add-WingetHistoryRecord {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Record)

    $path = Join-Path (Get-WingetDataDirectory) 'update-history.jsonl'
    $line = $Record | ConvertTo-Json -Compress -Depth 4
    Add-Content -LiteralPath $path -Value $line -Encoding UTF8
}

function Clear-WingetHistory {
    [CmdletBinding()]
    param()

    $path = Join-Path (Get-WingetDataDirectory) 'update-history.jsonl'
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
    }
}

function Write-WingetFailureLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $PackageId,
        [Parameter(Mandatory)][int] $ExitCode,
        [AllowEmptyString()][string] $Command = '',
        [AllowEmptyString()][string] $Message = ''
    )

    $safeId = ($PackageId -replace '[^a-zA-Z0-9._-]', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($safeId)) { $safeId = 'unknown-package' }
    $path = Join-Path (Get-WingetLogDirectory) ('{0}-{1}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $safeId)
    $content = @(
        'Winget Update Center - upgrade failure'
        'Timestamp: {0}' -f (Get-Date -Format 'o')
        'Package: {0}' -f $PackageId
        'Exit code: {0}' -f $ExitCode
        'Command: {0}' -f $Command
        ''
        'Winget output:'
        $Message
    )
    Set-Content -LiteralPath $path -Value $content -Encoding UTF8
    return $path
}

function Get-WingetSchedule {
    [CmdletBinding()]
    param()

    $path = Join-Path (Get-WingetDataDirectory) 'schedule.json'
    if (-not (Test-Path -LiteralPath $path)) {
        return [pscustomobject]@{ Frequency = 'Disabled'; Time = '09:00'; DayOfWeek = 'Monday' }
    }
    try { return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop) }
    catch { return [pscustomobject]@{ Frequency = 'Disabled'; Time = '09:00'; DayOfWeek = 'Monday' } }
}

function Set-WingetScanSchedule {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][ValidateSet('Disabled', 'Daily', 'Weekly')][string] $Frequency,
        [Parameter(Mandatory)][string] $Time,
        [ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')]
        [string] $DayOfWeek = 'Monday',
        [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string] $ScriptPath
    )

    $taskName = 'Winget Update Center Scan'
    if (-not $PSCmdlet.ShouldProcess($taskName, "Set scan schedule to $Frequency")) { return (Get-WingetSchedule) }
    Import-Module ScheduledTasks -ErrorAction Stop
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($Frequency -eq 'Disabled') {
        if ($existingTask) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
    }
    else {
        $scanTime = [datetime]::ParseExact($Time, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture)
        $trigger = if ($Frequency -eq 'Daily') {
            New-ScheduledTaskTrigger -Daily -At $scanTime
        }
        else {
            New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $scanTime
        }
        $powerShellPath = Join-Path ([Environment]::GetFolderPath('Windows')) 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $ScriptPath
        $action = New-ScheduledTaskAction -Execute $powerShellPath -Argument $arguments -WorkingDirectory (Split-Path $ScriptPath -Parent)
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        $userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Checks Winget for application updates and notifies the signed-in user.' -Force | Out-Null
    }

    $schedule = [pscustomobject]@{ Frequency = $Frequency; Time = $Time; DayOfWeek = $DayOfWeek }
    $schedule | ConvertTo-Json | Set-Content -LiteralPath (Join-Path (Get-WingetDataDirectory) 'schedule.json') -Encoding UTF8
    return $schedule
}

Export-ModuleMember -Function ConvertFrom-WingetTable, Get-WingetInventory, Invoke-WingetUpgrade, Invoke-WingetUpgradeAll, Get-WingetDataDirectory, Get-WingetLogDirectory, Get-WingetHistory, Add-WingetHistoryRecord, Clear-WingetHistory, Write-WingetFailureLog, Get-WingetSchedule, Set-WingetScanSchedule
