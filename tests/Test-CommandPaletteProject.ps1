$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$projectRoot = Join-Path $repositoryRoot 'WingetUpdateCenter.CommandPalette'
$manifestPath = Join-Path $projectRoot 'Package.appxmanifest'
$extensionPath = Join-Path $projectRoot 'WingetUpdateCenterExtension.cs'
$providerPath = Join-Path $projectRoot 'WingetUpdateCommandsProvider.cs'
$projectPath = Join-Path $projectRoot 'WingetUpdateCenter.CommandPalette.csproj'

[xml] $manifest = Get-Content -LiteralPath $manifestPath -Raw
$source = Get-Content -LiteralPath $extensionPath -Raw

$namespace = [System.Xml.XmlNamespaceManager]::new($manifest.NameTable)
$namespace.AddNamespace('f', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
$namespace.AddNamespace('uap3', 'http://schemas.microsoft.com/appx/manifest/uap/windows10/3')
$namespace.AddNamespace('com', 'http://schemas.microsoft.com/appx/manifest/com/windows10')

$classId = $manifest.SelectSingleNode('//com:Class', $namespace).Id
$activationId = $manifest.SelectSingleNode('//uap3:AppExtension/uap3:Properties/f:CmdPalProvider/f:Activation/f:CreateInstance', $namespace).ClassId
$sourceGuid = [regex]::Match($source, '\[Guid\("(?<id>[A-Fa-f0-9-]+)"\)\]').Groups['id'].Value

if ([string]::IsNullOrWhiteSpace($classId) -or $classId -ne $activationId -or $classId -ne $sourceGuid) {
    throw "The Command Palette COM CLSID must match in the manifest and extension source."
}

$appExtension = $manifest.SelectSingleNode('//uap3:AppExtension', $namespace)
if ($appExtension.Name -ne 'com.microsoft.commandpalette') {
    throw 'The Command Palette app extension registration is missing.'
}

$providerSource = Get-Content -LiteralPath $providerPath -Raw
$mainCommandId = [regex]::Match($providerSource, 'MainCommandId\s*=\s*"(?<id>[^"]+)"').Groups['id'].Value
$dockBandId = [regex]::Match($providerSource, 'DockBandId\s*=\s*"(?<id>[^"]+)"').Groups['id'].Value
if ([string]::IsNullOrWhiteSpace($mainCommandId) -or
    [string]::IsNullOrWhiteSpace($dockBandId) -or
    $mainCommandId -eq $dockBandId) {
    throw 'The top-level page and Dock band must use distinct, non-empty command IDs.'
}

if ($providerSource -match 'WrappedDockItem' -or $providerSource -notmatch 'WingetDockMenuPage') {
    throw 'The Dock must expose one expandable menu button instead of a multi-button strip.'
}

if ($providerSource -notmatch 'Title\s*=\s*string\.Empty' -or
    $providerSource -notmatch 'Subtitle\s*=\s*string\.Empty') {
    throw 'The Dock band must be icon-only while the expanded page retains its title.'
}

$updatesPageSource = Get-Content -LiteralPath (Join-Path $projectRoot 'Pages\WingetUpdatesPage.cs') -Raw
if ($updatesPageSource -notmatch 'new ProgressState' -or
    $updatesPageSource -notmatch 'IsIndeterminate\s*=\s*true' -or
    $updatesPageSource -notmatch 'ExtensionHost\.ShowStatus' -or
    $updatesPageSource -notmatch 'ExtensionHost\.HideStatus') {
    throw 'Winget operations must expose and dismiss a native Command Palette progress indicator.'
}

$accentSource = Get-Content -LiteralPath (Join-Path $projectRoot 'AccentVisuals.cs') -Raw
if ($accentSource -notmatch 'TagBackgroundAlpha\s*=\s*0x2E' -or
    $accentSource -match 'Foreground\s*=\s*new OptionalColor') {
    throw 'Status tags must use a subtle translucent background and theme-adaptive text.'
}

$iconNode = $manifest.SelectSingleNode('//uap3:AppExtension/uap3:Properties/f:Icon', $namespace)
if ($null -eq $iconNode -or $iconNode.InnerText -ne 'Assets\StoreLogo.png') {
    throw 'The Command Palette extension icon is missing from the app extension manifest.'
}

$requiredAssets = @(
    'Assets\StoreLogo.png',
    'Assets\DockIconLight.svg',
    'Assets\DockIconDark.svg',
    'Assets\CheckAccent.svg',
    'Assets\UpdateAccent.svg',
    'Assets\UpdatedAccent.svg',
    'Assets\Square44x44Logo.scale-200.png',
    'Assets\Square44x44Logo.targetsize-24_altform-unplated.png',
    'Assets\Square150x150Logo.scale-200.png',
    'Assets\Wide310x150Logo.scale-200.png',
    'Assets\SplashScreen.scale-200.png',
    'Assets\LockScreenLogo.scale-200.png'
)
foreach ($asset in $requiredAssets) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $asset) -PathType Leaf)) {
        throw "Required Command Palette asset is missing: $asset"
    }
}

$projectSource = Get-Content -LiteralPath $projectPath -Raw
if ($projectSource -notmatch 'CopyToOutputDirectory>PreserveNewest' -or
    $projectSource -notmatch 'CopyToPublishDirectory>PreserveNewest') {
    throw 'Runtime icon assets must be copied beside the extension executable.'
}

[xml] $project = $projectSource
$releaseVersion = $manifest.Package.Identity.Version
$packageVersion = $project.SelectSingleNode('/Project/PropertyGroup/AppxPackageVersion').InnerText
$packageIdentityName = $project.SelectSingleNode('/Project/PropertyGroup/AppxPackageIdentityName').InnerText
$packagePublisher = $project.SelectSingleNode('/Project/PropertyGroup/AppxPackagePublisher').InnerText
$assemblyVersion = $project.SelectSingleNode('/Project/PropertyGroup/AssemblyVersion').InnerText
$fileVersion = $project.SelectSingleNode('/Project/PropertyGroup/FileVersion').InnerText
$informationalVersion = $project.SelectSingleNode('/Project/PropertyGroup/InformationalVersion').InnerText
$applicationManifest = [xml] (Get-Content -LiteralPath (Join-Path $projectRoot 'app.manifest') -Raw)
if ($releaseVersion -ne $packageVersion -or
    $releaseVersion -ne $assemblyVersion -or
    $releaseVersion -ne $fileVersion -or
    $releaseVersion -ne $informationalVersion -or
    $releaseVersion -ne $applicationManifest.assembly.assemblyIdentity.version) {
    throw 'MSIX, assembly, and application manifest versions must match.'
}

if ($manifest.Package.Identity.Name -ne $packageIdentityName -or
    $manifest.Package.Identity.Publisher -ne $packagePublisher) {
    throw 'MSIX identity name and publisher must match between the project and package manifest.'
}

$releaseTrimming = $project.SelectSingleNode('/Project/PropertyGroup[@Condition="''$(Configuration)''!=''Debug''"]/PublishTrimmed')
if ($null -eq $releaseTrimming -or $releaseTrimming.InnerText -ne 'false') {
    throw 'Release builds must keep trimming disabled for the WinRT extension dependencies.'
}

$parserSource = Get-Content -LiteralPath (Join-Path $projectRoot 'Services\WingetTableParser.cs') -Raw
if ($parserSource -notmatch 'SeparatorRegex' -or $parserSource -notmatch 'SliceColumns') {
    throw 'The Winget table parser implementation is incomplete.'
}

Write-Output 'All Command Palette project structure checks passed.'
