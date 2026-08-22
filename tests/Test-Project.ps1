$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$powerShellFiles = @(
    Get-ChildItem -Path $repositoryRoot -Recurse -File -Include '*.ps1', '*.psm1' |
        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
)
$textFiles = @(
    Get-ChildItem -Path $repositoryRoot -Recurse -File -Include '*.ps1', '*.psm1', '*.md', '*.cmd', '*.yml', '*.yaml' |
        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
)

foreach ($file in $powerShellFiles) {
    $tokens = $null
    $parseErrors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        throw "PowerShell parser error in $($file.FullName): $($parseErrors[0].Message)"
    }
}

& (Join-Path $PSScriptRoot 'Test-WingetCore.ps1')

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$uiPath = Join-Path $repositoryRoot 'WingetUpdater.ps1'
$uiSource = [IO.File]::ReadAllText($uiPath)
$xamlBlocks = [regex]::Matches($uiSource, '(?s)\[xml\] \$(?:xaml|dialogXaml) = @''\r?\n(.*?)\r?\n''@')
if ($xamlBlocks.Count -ne 2) { throw "Expected two embedded XAML documents; found $($xamlBlocks.Count)." }
foreach ($block in $xamlBlocks) {
    [xml] $xml = $block.Groups[1].Value
    $reader = [Xml.XmlNodeReader]::new($xml)
    $null = [Windows.Markup.XamlReader]::Load($reader)
}

$approvedVerbs = @(Get-Verb | ForEach-Object { $_.Verb })
foreach ($file in $powerShellFiles) {
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    $functions = $ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst]
    }, $true)
    foreach ($function in $functions) {
        if ($function.Name -notmatch '-') { continue }
        $verb = ($function.Name -split '-', 2)[0]
        if ($verb -notin $approvedVerbs) {
            throw "Unapproved PowerShell verb in $($file.FullName): $($function.Name)"
        }
    }
}

foreach ($file in $textFiles) {
    $lineNumber = 0
    foreach ($line in [IO.File]::ReadAllLines($file.FullName)) {
        $lineNumber++
        if ($line -match '[ \t]+$') { throw "Trailing whitespace in $($file.FullName) at line $lineNumber." }
    }
    $text = [IO.File]::ReadAllText($file.FullName)
    if ($text.ToCharArray() | Where-Object { [int]$_ -gt 127 } | Select-Object -First 1) {
        throw "Non-ASCII text in $($file.FullName) can be decoded incorrectly by Windows PowerShell 5.1."
    }
}

$requiredFiles = @(
    'README.md', '.gitignore', '.gitattributes', 'Launch-Winget-Updater.cmd',
    'WingetCore.psm1', 'WingetScheduledScan.ps1', 'WingetUpdater.ps1'
)
foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relativePath) -PathType Leaf)) {
        throw "Required repository file is missing: $relativePath"
    }
}

$analyzer = Get-Module -ListAvailable PSScriptAnalyzer | Select-Object -First 1
if ($analyzer) {
    Import-Module PSScriptAnalyzer
    $findings = @(Invoke-ScriptAnalyzer -Path $powerShellFiles.FullName -Severity Warning, Error)
    if ($findings.Count -gt 0) {
        $findings | Format-Table -AutoSize
        throw 'PSScriptAnalyzer findings remain.'
    }
}

Write-Output 'All project validation checks passed.'
