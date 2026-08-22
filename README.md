# Winget Update Center

Winget Update Center is a self-contained Windows PowerShell application for reviewing installed software, checking available versions, and applying updates through Windows Package Manager (`winget`).

It provides a graphical interface, persistent update history, detailed failure logs, CSV exports, and optional scheduled update checks without requiring third-party PowerShell modules or external accounts.

> [!NOTE]
> This is a community tool and is not an official Microsoft application. It is designed for Windows and depends on Winget and WPF.

## Features

- View every application detected by `winget list`
- See installed and available versions in separate columns
- Search by application name, package ID, or version
- Upgrade one package, several selected packages, or every available package
- Request silent installation when supported by the installer
- Export installed applications, available updates, or update history to CSV
- Record each update attempt with its previous version, target version, result, and exit code
- Write complete Winget output to a separate log when an upgrade fails
- Schedule daily or weekly update checks with Windows notifications
- Keep scans and updates responsive by running Winget work in background jobs
- Store all runtime data under the current Windows user profile

## Requirements

- Windows 10 version 1809 or later, or Windows 11
- [App Installer / Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/)
- Windows PowerShell 5.1

PowerShell 7 can run the main script directly, but the included launcher and scheduled task use the built-in Windows PowerShell 5.1 host for maximum WPF compatibility.

Confirm that Winget is installed:

```powershell
winget --version
```

If the command is unavailable, install or update **App Installer** from the Microsoft Store.

## Quick start

1. Download the repository as a ZIP file and extract it, or clone it with Git.
2. Keep the PowerShell module and scripts together in the same directory.
3. Double-click `Launch-Winget-Updater.cmd`.
4. Allow the initial Winget scan to finish.

You can also launch it from a terminal:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\WingetUpdater.ps1
```

The execution-policy option applies only to this process. It does not modify the machine or user execution-policy configuration.

## Using the application

### Review available updates

The **Updates available** tab displays:

- Application name
- Installed version
- Available version
- Winget package ID
- Package source

Use the search box to filter the current tab. Select multiple packages with `Ctrl` or `Shift`.

### Install updates

- **Upgrade selected** processes the selected rows individually.
- **Upgrade all** processes every available package individually and records a result for each package.
- **Request silent installation** adds Winget's `--silent` option. Individual installers can ignore or reject this option.

Some installers require elevation or interactive input. If an update fails because of permissions, close the application and run `Launch-Winget-Updater.cmd` as Administrator.

### Review installed software

The **All installed** tab shows applications Winget can detect from package-manager registrations and Windows uninstall records. Portable programs and manually copied executables might not appear.

### Export a report

Select the relevant tab and choose **Export CSV**. The exported columns match the selected inventory or history view.

## Update history and failure logs

The **Update history** tab is loaded automatically every time the application starts. Each attempted package upgrade records:

- Date and time
- Application and package ID
- Previous version
- Target version
- Success or failure
- Winget exit code

Failed upgrades also receive a detailed text log containing the command, exit code, and Winget output.

- Double-click a failed history row to open its log in Notepad.
- Choose **Open logs** to open the complete log directory.
- **Clear history** removes history records but deliberately keeps detailed failure logs.

## Scheduled scans

Choose **Schedule scans** to configure a daily or weekly background check. The application creates a current-user Windows Scheduled Task named:

```text
Winget Update Center Scan
```

The scheduled task runs `WingetScheduledScan.ps1` in a hidden Windows PowerShell process. It checks for updates, writes the latest result, displays a Windows notification when updates are available or the scan fails, and then exits.

Scheduled scans:

- Do not remain running between checks
- Never install updates automatically
- Require the user to be signed in to display notifications
- Are configured to run when next available if the original time was missed
- Can be removed by selecting **Disabled** in the schedule dialog

Creating or changing a scheduled task can require administrator approval on managed computers.

## Persistent data

Runtime data is stored outside the repository under:

```text
%LOCALAPPDATA%\WingetUpdateCenter
```

| Path | Purpose |
| --- | --- |
| `update-history.jsonl` | Persistent update-attempt history |
| `Logs\` | Detailed logs for failed upgrades |
| `last-scan.json` | Most recent scheduled-scan result |
| `schedule.json` | Saved schedule selection |

Data is isolated per Windows user. Removing the repository does not automatically delete this data or an enabled scheduled task.

## Privacy and security

- The tool does not require an online account, API key, or credential.
- It does not add telemetry or send history files to another service.
- Winget still contacts the package sources configured on the computer to retrieve package metadata and installers.
- History and logs can contain installed application names, versions, package IDs, and installer output. Review logs before sharing them publicly.
- Package installation is performed by Winget and each package's installer. Review the selected package source and publisher before installing unfamiliar software.

## Troubleshooting

### Winget was not found

Install or update **App Installer** from the Microsoft Store, open a new terminal, and verify `winget --version`.

### No applications or updates are displayed

Run these commands in a terminal to compare their output with the application:

```powershell
winget list
winget list --upgrade-available --include-unknown
```

An empty Updates tab can simply mean that no applicable updates are available.

### An update failed

Open the **Update history** tab and double-click the failed row. Common causes include:

- Administrator privileges are required
- The installer does not support silent mode
- The application is currently running
- The package source is temporarily unavailable
- The installer returned a vendor-specific error

### Scheduled scans do not run

1. Open `taskschd.msc`.
2. Find **Winget Update Center Scan** in Task Scheduler Library.
3. Review its last-run time and result.
4. Confirm that the script directory still exists.
5. Re-save the schedule from the application if the repository was moved.

## Project structure

```text
.
|-- .github/
|   `-- workflows/
|       `-- test.yml
|-- tests/
|   |-- Test-Project.ps1
|   `-- Test-WingetCore.ps1
|-- Launch-Winget-Updater.cmd
|-- PSScriptAnalyzerSettings.psd1
|-- WingetCore.psm1
|-- WingetScheduledScan.ps1
|-- WingetUpdater.ps1
`-- README.md
```

| File | Purpose |
| --- | --- |
| `WingetUpdater.ps1` | WPF interface and background-job orchestration |
| `WingetCore.psm1` | Winget process runner, parser, history, logging, and schedule helpers |
| `WingetScheduledScan.ps1` | Noninteractive scheduled scan and notification entry point |
| `Launch-Winget-Updater.cmd` | Double-click launcher using Windows PowerShell 5.1 |
| `PSScriptAnalyzerSettings.psd1` | Cross-version lint policy for intentional analyzer exceptions |
| `tests/Test-WingetCore.ps1` | Offline parser and persistence regression tests |
| `tests/Test-Project.ps1` | Repository-wide syntax, XAML, and lint checks |

## Development and testing

The tests do not install packages, create a real scheduled task, or require Winget network access.

Run all checks with Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Project.ps1
```

The GitHub Actions workflow runs the same command on `windows-latest` for pushes, pull requests, and manual workflow dispatches.

## Contributing

Issues and pull requests are welcome. Please include:

- Windows and PowerShell versions
- Winget version
- Relevant error text or exit code
- Reproduction steps

Remove personal information from exported inventories and logs before attaching them to an issue.
