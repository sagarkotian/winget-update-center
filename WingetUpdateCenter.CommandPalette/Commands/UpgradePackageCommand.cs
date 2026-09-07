using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace WingetUpdateCenter.CommandPalette;

internal sealed partial class UpgradePackageCommand : InvokableCommand
{
    private readonly WingetUpdatesPage _page;
    private readonly WingetPackage _package;

    public UpgradePackageCommand(WingetUpdatesPage page, WingetPackage package)
    {
        _page = page;
        _package = package;
        Id = $"com.wingetupdatecenter.update.{SanitizeId(package.Id)}";
        Name = $"Update {package.Name}";
        Icon = AccentVisuals.UpdateIcon();
    }

    public override ICommandResult Invoke()
    {
        _page.Upgrade(_package);
        return CommandResult.KeepOpen();
    }

    private static string SanitizeId(string value) => string.Concat(
        value.Select(character => char.IsLetterOrDigit(character) || character is '.' or '-' ? character : '_'));
}
