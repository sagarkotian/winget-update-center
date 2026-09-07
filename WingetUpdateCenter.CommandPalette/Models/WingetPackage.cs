namespace WingetUpdateCenter.CommandPalette;

internal sealed record WingetPackage(
    string Name,
    string Id,
    string InstalledVersion,
    string AvailableVersion,
    string Source)
{
    public bool HasUpdate => !string.IsNullOrWhiteSpace(AvailableVersion);
}

internal sealed record WingetInventory(
    IReadOnlyList<WingetPackage> Installed,
    DateTimeOffset CheckedAt);

internal sealed record WingetCommandResult(
    int ExitCode,
    string Output,
    string Error)
{
    public bool Succeeded => ExitCode == 0;

    public string CombinedOutput => string.Join(
        Environment.NewLine,
        new[] { Output, Error }.Where(value => !string.IsNullOrWhiteSpace(value)));
}
