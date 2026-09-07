using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace WingetUpdateCenter.CommandPalette;

internal sealed partial class WingetDockMenuPage : ContentPage
{
    public WingetDockMenuPage(WingetUpdatesPage updatesPage)
    {
        Id = WingetUpdateCommandsProvider.DockBandId;
        Title = "Winget Update Center";
        Name = "Open actions";
        Icon = AccentVisuals.DockIcon();
        Commands =
        [
            new CommandContextItem(updatesPage)
            {
                Title = "Review installed apps",
                Subtitle = "Open the installed-app inventory and available updates",
                Icon = AccentVisuals.UpdatedIcon(),
            },
            new CommandContextItem(new RefreshCommand(updatesPage))
            {
                Title = "Check for updates",
                Subtitle = "Refresh the installed-app inventory",
                Icon = AccentVisuals.CheckedIcon(),
            },
            new CommandContextItem(new UpgradeAllCommand(updatesPage))
            {
                Title = "Update all",
                Subtitle = "Install every available update with Winget",
                Icon = AccentVisuals.UpdateIcon(),
            },
        ];
    }

    public override IContent[] GetContent() =>
    [
        new MarkdownContent(
            "### Winget Update Center\n\nUse **More actions** to review installed apps, check again, or update everything."),
    ];
}
