using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace WingetUpdateCenter.CommandPalette;

internal sealed partial class UpgradeAllCommand : InvokableCommand
{
    internal const string CommandId = "com.wingetupdatecenter.update-all";

    private readonly WingetUpdatesPage _page;

    public UpgradeAllCommand(WingetUpdatesPage page)
    {
        _page = page;
        Id = CommandId;
        Name = "Update all available apps";
        Icon = AccentVisuals.UpdateIcon();
    }

    public override ICommandResult Invoke()
    {
        _page.UpgradeAll();
        return CommandResult.KeepOpen();
    }
}
