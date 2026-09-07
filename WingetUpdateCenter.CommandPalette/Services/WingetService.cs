using System.ComponentModel;
using System.Diagnostics;
using System.Text;

namespace WingetUpdateCenter.CommandPalette;

internal sealed class WingetService
{
    private static readonly string[] CommonArguments =
    [
        "--accept-source-agreements",
        "--disable-interactivity",
    ];

    private readonly string _wingetExecutable = FindWingetExecutable();

    public async Task<WingetInventory> GetInventoryAsync(CancellationToken cancellationToken = default)
    {
        WingetCommandResult installedResult = await RunAsync(
            ["list", .. CommonArguments],
            cancellationToken).ConfigureAwait(false);

        if (!installedResult.Succeeded)
        {
            throw CreateCommandException("Winget could not read the installed applications", installedResult);
        }

        WingetCommandResult upgradesResult = await RunAsync(
            ["list", "--upgrade-available", "--include-unknown", .. CommonArguments],
            cancellationToken).ConfigureAwait(false);
        if (!upgradesResult.Succeeded)
        {
            throw CreateCommandException("Winget could not check for available updates", upgradesResult);
        }

        IReadOnlyList<WingetPackage> installed = WingetTableParser.Parse(installedResult.Output, false);
        IReadOnlyList<WingetPackage> upgrades = WingetTableParser.Parse(upgradesResult.Output, true);
        Dictionary<string, WingetPackage> updatesById = upgrades
            .GroupBy(package => package.Id, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase);

        WingetPackage[] merged = installed
            .Select(package => MergeUpdate(package, updatesById))
            .OrderByDescending(package => package.HasUpdate)
            .ThenBy(package => package.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        return new WingetInventory(merged, DateTimeOffset.Now);
    }

    public Task<WingetCommandResult> UpgradeAsync(
        WingetPackage package,
        CancellationToken cancellationToken = default)
    {
        List<string> arguments = ["upgrade"];
        if (package.Id.EndsWith("...", StringComparison.Ordinal) || package.Id.EndsWith('\u2026'))
        {
            arguments.AddRange(["--name", package.Name]);
        }
        else
        {
            arguments.AddRange(["--id", package.Id]);
        }

        arguments.AddRange(
        [
            "--exact",
            "--accept-package-agreements",
            .. CommonArguments,
        ]);
        return RunAsync(arguments, cancellationToken);
    }

    public Task<WingetCommandResult> UpgradeAllAsync(CancellationToken cancellationToken = default) => RunAsync(
        [
            "upgrade",
            "--all",
            "--include-unknown",
            "--accept-package-agreements",
            .. CommonArguments,
        ],
        cancellationToken);

    private static WingetPackage MergeUpdate(
        WingetPackage installed,
        Dictionary<string, WingetPackage> updatesById)
    {
        if (!updatesById.TryGetValue(installed.Id, out WingetPackage? update))
        {
            return installed;
        }

        return installed with
        {
            AvailableVersion = update.AvailableVersion,
            Source = string.IsNullOrWhiteSpace(update.Source) ? installed.Source : update.Source,
        };
    }

    private async Task<WingetCommandResult> RunAsync(
        IReadOnlyCollection<string> arguments,
        CancellationToken cancellationToken)
    {
        ProcessStartInfo startInfo = new()
        {
            FileName = _wingetExecutable,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = new UTF8Encoding(false),
            StandardErrorEncoding = new UTF8Encoding(false),
        };
        foreach (string argument in arguments)
        {
            startInfo.ArgumentList.Add(argument);
        }

        using Process process = new() { StartInfo = startInfo };
        try
        {
            if (!process.Start())
            {
                throw new InvalidOperationException("Winget could not be started.");
            }
        }
        catch (Win32Exception exception)
        {
            throw new InvalidOperationException(
                "Winget was not found. Install or update App Installer from the Microsoft Store, then try again.",
                exception);
        }

        Task<string> outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
        Task<string> errorTask = process.StandardError.ReadToEndAsync(cancellationToken);
        await process.WaitForExitAsync(cancellationToken).ConfigureAwait(false);
        string output = await outputTask.ConfigureAwait(false);
        string error = await errorTask.ConfigureAwait(false);
        return new WingetCommandResult(process.ExitCode, output, error);
    }

    private static string FindWingetExecutable()
    {
        string? overridePath = Environment.GetEnvironmentVariable("WINGET_EXE_PATH");
        if (!string.IsNullOrWhiteSpace(overridePath))
        {
            return overridePath;
        }

        string alias = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Microsoft",
            "WindowsApps",
            "winget.exe");
        return File.Exists(alias) ? alias : "winget.exe";
    }

    private static InvalidOperationException CreateCommandException(string message, WingetCommandResult result)
    {
        string detail = result.CombinedOutput.Trim();
        if (detail.Length > 600)
        {
            detail = detail[..600];
        }

        return new InvalidOperationException(string.IsNullOrWhiteSpace(detail) ? message : $"{message}: {detail}");
    }
}
