using System.Text.RegularExpressions;

namespace WingetUpdateCenter.CommandPalette;

internal static partial class WingetTableParser
{
    private static readonly string[] NewLineSeparators = ["\r\n", "\n"];

    public static IReadOnlyList<WingetPackage> Parse(string output, bool upgradeTable)
    {
        string[] lines = AnsiSequenceRegex()
            .Replace(output ?? string.Empty, string.Empty)
            .Split(NewLineSeparators, StringSplitOptions.None)
            .Select(line => ControlCharacterRegex().Replace(line, string.Empty).TrimEnd())
            .ToArray();

        int separatorIndex = FindSeparator(lines);
        if (separatorIndex < 1)
        {
            return [];
        }

        MatchCollection headers = HeaderFieldRegex().Matches(lines[separatorIndex - 1]);
        int[] starts = headers.Select(match => match.Index).ToArray();
        if (starts.Length < 3)
        {
            return [];
        }

        List<WingetPackage> packages = [];
        for (int lineIndex = separatorIndex + 1; lineIndex < lines.Length; lineIndex++)
        {
            string line = lines[lineIndex];
            if (string.IsNullOrWhiteSpace(line) || SpinnerRegex().IsMatch(line))
            {
                continue;
            }

            string[] values = SliceColumns(line, starts);
            if (values.Length < 3 || string.IsNullOrWhiteSpace(values[1]))
            {
                continue;
            }

            string available = string.Empty;
            string source = string.Empty;
            if (values.Length >= 5)
            {
                available = values[3];
                source = values[4];
            }
            else if (values.Length == 4)
            {
                if (upgradeTable)
                {
                    available = values[3];
                }
                else
                {
                    source = values[3];
                }
            }

            packages.Add(new WingetPackage(values[0], values[1], values[2], available, source));
        }

        return packages;
    }

    private static int FindSeparator(string[] lines)
    {
        for (int index = 1; index < lines.Length; index++)
        {
            if (!SeparatorRegex().IsMatch(lines[index]))
            {
                continue;
            }

            if (HeaderFieldRegex().Count(lines[index - 1]) >= 3)
            {
                return index;
            }
        }

        return -1;
    }

    private static string[] SliceColumns(string line, int[] starts)
    {
        string[] values = new string[starts.Length];
        for (int column = 0; column < starts.Length; column++)
        {
            int start = starts[column];
            if (start >= line.Length)
            {
                values[column] = string.Empty;
                continue;
            }

            int length = column < starts.Length - 1
                ? Math.Min(starts[column + 1] - start, line.Length - start)
                : line.Length - start;
            values[column] = line.Substring(start, length).Trim();
        }

        return values;
    }

    [GeneratedRegex("\\x1B\\[[0-?]*[ -/]*[@-~]", RegexOptions.Compiled)]
    private static partial Regex AnsiSequenceRegex();

    [GeneratedRegex("[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F]", RegexOptions.Compiled)]
    private static partial Regex ControlCharacterRegex();

    [GeneratedRegex(@"\S(?:.*?\S)?(?=\s{2,}|$)", RegexOptions.Compiled)]
    private static partial Regex HeaderFieldRegex();

    [GeneratedRegex(@"^\s*-{3,}(?:\s+-{2,})*\s*$", RegexOptions.Compiled)]
    private static partial Regex SeparatorRegex();

    [GeneratedRegex(@"^\s*[-\\|/]\s*$", RegexOptions.Compiled)]
    private static partial Regex SpinnerRegex();
}
