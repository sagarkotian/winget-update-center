using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace WingetUpdateCenter.CommandPalette;

internal static class AccentVisuals
{
    private const byte TagBackgroundAlpha = 0x2E;

    internal static IconInfo DockIcon() => IconHelpers.FromRelativePaths(
        "Assets\\DockIconLight.svg",
        "Assets\\DockIconDark.svg");

    internal static IconInfo CheckedIcon() => IconHelpers.FromRelativePath("Assets\\CheckAccent.svg");

    internal static IconInfo UpdateIcon() => IconHelpers.FromRelativePath("Assets\\UpdateAccent.svg");

    internal static IconInfo UpdatedIcon() => IconHelpers.FromRelativePath("Assets\\UpdatedAccent.svg");

    internal static ITag CheckedTag() => CreateTag("Checked", 0x00, 0x78, 0xD4);

    internal static ITag UpdateTag(string text = "Update available") =>
        CreateTag(text, 0xF7, 0x63, 0x0C);

    internal static ITag UpdatedTag() => CreateTag("Up to date", 0x10, 0x7C, 0x10);

    private static Tag CreateTag(
        string text,
        byte backgroundRed,
        byte backgroundGreen,
        byte backgroundBlue) => new(text)
        {
            Background = new OptionalColor(
                true,
                new Color(backgroundRed, backgroundGreen, backgroundBlue, TagBackgroundAlpha)),
            ToolTip = text,
        };
}
