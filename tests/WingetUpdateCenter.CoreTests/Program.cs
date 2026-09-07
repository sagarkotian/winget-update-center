using WingetUpdateCenter.CommandPalette;

TestEmptyOutput();
TestUpgradeTable();
TestInstalledTableWithoutUpdates();
TestControlSequenceRemoval();

Console.WriteLine("All C# Winget parser tests passed.");

static void TestEmptyOutput()
{
    Assert(WingetTableParser.Parse(string.Empty, true).Count == 0, "Empty output should return no packages.");
}

static void TestUpgradeTable()
{
    const string output = """
        Name               Id                     Version  Available  Source
        -------------------------------------------------------------------
        Microsoft Edge     Microsoft.Edge         130.0.1  131.0.1    winget
        PowerToys          Microsoft.PowerToys    0.98.0   0.99.0     winget
        """;

    IReadOnlyList<WingetPackage> packages = WingetTableParser.Parse(output, true);
    Assert(packages.Count == 2, "Two upgrade rows should be parsed.");
    Assert(packages[0].Id == "Microsoft.Edge", "The package ID should be read from its column.");
    Assert(packages[0].AvailableVersion == "131.0.1", "The available version should be parsed.");
    Assert(packages[1].Source == "winget", "The source should be parsed.");
}

static void TestInstalledTableWithoutUpdates()
{
    const string output = """
        Name              Id                    Version  Source
        -------------------------------------------------------
        Windows Terminal  Microsoft.Terminal    1.23.1   winget
        """;

    IReadOnlyList<WingetPackage> packages = WingetTableParser.Parse(output, false);
    Assert(packages.Count == 1, "One installed app should be parsed.");
    Assert(packages[0].Source == "winget", "A four-column installed table uses its fourth column as source.");
    Assert(!packages[0].HasUpdate, "An installed-only row should not be marked as updatable.");
}

static void TestControlSequenceRemoval()
{
    const string output = "\u001b[32mName        Id             Version  Available  Source\u001b[0m\n" +
        "---------------------------------------------------------\n" +
        "Contoso App Contoso.App    1.0      2.0        winget\n";

    IReadOnlyList<WingetPackage> packages = WingetTableParser.Parse(output, true);
    Assert(packages.Count == 1, "ANSI sequences should not prevent table parsing.");
    Assert(packages[0].Name == "Contoso App", "The app name should remain intact after cleanup.");
}

static void Assert(bool condition, string message)
{
    if (!condition)
    {
        throw new InvalidOperationException(message);
    }
}
