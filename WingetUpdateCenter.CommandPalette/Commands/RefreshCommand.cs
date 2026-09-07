using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace WingetUpdateCenter.CommandPalette;

internal sealed partial class RefreshCommand : InvokableCommand
{
    internal const string CommandId = "com.wingetupdatecenter.refresh";

    private readonly WingetUpdatesPage _page;

    public RefreshCommand(WingetUpdatesPage page)
    {
        _page = page;
        Id = CommandId;
        Name = "Check for updates";
        Icon = AccentVisuals.CheckedIcon();
    }

    public override ICommandResult Invoke()
    {
        _page.Refresh();
        return CommandResult.KeepOpen();
    }
}
