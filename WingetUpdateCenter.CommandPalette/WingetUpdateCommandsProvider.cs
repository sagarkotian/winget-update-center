using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace WingetUpdateCenter.CommandPalette;

public sealed partial class WingetUpdateCommandsProvider : CommandProvider
{
    internal const string MainCommandId = "com.wingetupdatecenter.updates";
    internal const string DockBandId = "com.wingetupdatecenter.dock";

    private readonly WingetUpdatesPage _page;
    private readonly WingetDockMenuPage _dockMenuPage;
    private readonly CommandItem _topLevelCommand;
    private readonly ICommandItem _dockBand;

    public WingetUpdateCommandsProvider()
    {
        Id = "com.wingetupdatecenter";
        DisplayName = "Winget Update Center";
        Icon = AccentVisuals.DockIcon();

        _page = new WingetUpdatesPage(new WingetService())
        {
            Id = MainCommandId,
        };

        _dockMenuPage = new WingetDockMenuPage(_page);

        _topLevelCommand = new CommandItem(_page)
        {
            Title = DisplayName,
            Subtitle = "Review installed apps and available updates",
            Icon = AccentVisuals.DockIcon(),
        };

        _dockBand = new CommandItem(_dockMenuPage)
        {
            Title = string.Empty,
            Subtitle = string.Empty,
            Icon = Icon,
        };
    }

    public override ICommandItem[] TopLevelCommands() => [_topLevelCommand];

    public override ICommandItem[] GetDockBands() => [_dockBand];

    public override ICommand? GetCommand(string id) => id switch
    {
        MainCommandId => _page,
        DockBandId => _dockMenuPage,
        RefreshCommand.CommandId => new RefreshCommand(_page),
        UpgradeAllCommand.CommandId => new UpgradeAllCommand(_page),
        _ => null,
    };

    public override ICommandItem? GetCommandItem(string id) => id switch
    {
        MainCommandId => _topLevelCommand,
        DockBandId => _dockBand,
        _ => null,
    };
}
