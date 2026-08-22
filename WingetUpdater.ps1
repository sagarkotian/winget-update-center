[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $hostPath = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    Start-Process -FilePath $hostPath -ArgumentList @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath))
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$modulePath = Join-Path $PSScriptRoot 'WingetCore.psm1'
Import-Module $modulePath -Force

[xml] $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Winget Update Center" Width="1120" Height="720" MinWidth="850" MinHeight="560"
        WindowStartupLocation="CenterScreen" Background="#F4F6FA" FontFamily="Segoe UI">
    <Window.Resources>
        <SolidColorBrush x:Key="Accent" Color="#2563EB"/>
        <Style TargetType="Button">
            <Setter Property="Padding" Value="15,8"/><Setter Property="Margin" Value="0,0,8,0"/>
            <Setter Property="Cursor" Value="Hand"/><Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Background" Value="#E8EEF9"/><Setter Property="Foreground" Value="#233250"/>
        </Style>
        <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{StaticResource Accent}"/><Setter Property="Foreground" Value="White"/>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="#EEF2F7"/><Setter Property="Foreground" Value="#475467"/>
            <Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Padding" Value="10,9"/>
            <Setter Property="BorderBrush" Value="#E1E6EF"/><Setter Property="BorderThickness" Value="0,0,1,1"/>
        </Style>
        <Style TargetType="DataGridCell">
            <Setter Property="Padding" Value="10,7"/><Setter Property="BorderThickness" Value="0,0,0,1"/>
            <Setter Property="BorderBrush" Value="#EEF1F5"/>
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="Padding" Value="18,9"/><Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#172033" Padding="26,20">
            <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                    <TextBlock Text="Winget Update Center" Foreground="White" FontSize="25" FontWeight="SemiBold"/>
                    <TextBlock Text="Installed applications, available versions, and updates in one place" Foreground="#B9C4D8" Margin="0,5,0,0"/>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Border Background="#26334B" CornerRadius="5" Padding="14,9" Margin="0,0,10,0">
                        <StackPanel><TextBlock x:Name="UpdateCountText" Text="-" Foreground="White" FontSize="19" HorizontalAlignment="Center"/>
                        <TextBlock Text="UPDATES" Foreground="#AAB7CE" FontSize="10"/></StackPanel>
                    </Border>
                    <Border Background="#26334B" CornerRadius="5" Padding="14,9">
                        <StackPanel><TextBlock x:Name="InstalledCountText" Text="-" Foreground="White" FontSize="19" HorizontalAlignment="Center"/>
                        <TextBlock Text="INSTALLED" Foreground="#AAB7CE" FontSize="10"/></StackPanel>
                    </Border>
                </StackPanel>
            </Grid>
        </Border>

        <Border Grid.Row="1" Background="White" BorderBrush="#DFE4EC" BorderThickness="0,0,0,1" Padding="20,12">
            <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="300"/></Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal">
                    <Button x:Name="RefreshButton" Content="Refresh" Style="{StaticResource PrimaryButton}"/>
                    <Button x:Name="ExportButton" Content="Export CSV"/>
                    <Button x:Name="ScheduleButton" Content="Schedule scans"/>
                </StackPanel>
                <CheckBox x:Name="SilentCheckBox" Grid.Column="1" Content="Request silent installation" VerticalAlignment="Center" Margin="8,0,0,0"
                          ToolTip="Adds --silent. Some installers may ignore this option."/>
                <Border Grid.Column="2" BorderBrush="#CCD3DE" BorderThickness="1" CornerRadius="4" Background="#FAFBFC" Padding="9,5">
                    <DockPanel><TextBlock Text="Search" Foreground="#98A2B3" Margin="0,0,8,0" VerticalAlignment="Center"/>
                    <TextBox x:Name="SearchBox" BorderThickness="0" Background="Transparent" VerticalContentAlignment="Center"/></DockPanel>
                </Border>
            </Grid>
        </Border>

        <TabControl x:Name="MainTabs" Grid.Row="2" Margin="20,16,20,12" Background="White" BorderBrush="#DDE3EC">
            <TabItem Header="Updates available">
                <Grid>
                    <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <DataGrid x:Name="UpdatesGrid" Grid.Row="0" AutoGenerateColumns="False" IsReadOnly="True" SelectionMode="Extended"
                              SelectionUnit="FullRow" GridLinesVisibility="None" HeadersVisibility="Column" RowHeaderWidth="0"
                              Background="White" BorderThickness="0" AlternatingRowBackground="#FAFBFD">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Application" Binding="{Binding Name}" Width="2*"/>
                            <DataGridTextColumn Header="Installed" Binding="{Binding InstalledVersion}" Width="*"/>
                            <DataGridTextColumn Header="Available" Binding="{Binding AvailableVersion}" Width="*"/>
                            <DataGridTextColumn Header="Package ID" Binding="{Binding Id}" Width="2*"/>
                            <DataGridTextColumn Header="Source" Binding="{Binding Source}" Width="*"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    <Border Grid.Row="1" Background="#F8FAFC" BorderBrush="#E3E8F0" BorderThickness="0,1,0,0" Padding="12">
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                            <Button x:Name="UpgradeSelectedButton" Content="Upgrade selected" Style="{StaticResource PrimaryButton}" IsEnabled="False"/>
                            <Button x:Name="UpgradeAllButton" Content="Upgrade all" IsEnabled="False" Margin="0"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </TabItem>
            <TabItem Header="All installed">
                <DataGrid x:Name="InstalledGrid" AutoGenerateColumns="False" IsReadOnly="True" SelectionMode="Extended"
                          SelectionUnit="FullRow" GridLinesVisibility="None" HeadersVisibility="Column" RowHeaderWidth="0"
                          Background="White" BorderThickness="0" AlternatingRowBackground="#FAFBFD">
                    <DataGrid.Columns>
                        <DataGridTextColumn Header="Application" Binding="{Binding Name}" Width="2*"/>
                        <DataGridTextColumn Header="Installed version" Binding="{Binding InstalledVersion}" Width="*"/>
                        <DataGridTextColumn Header="Available" Binding="{Binding AvailableVersion}" Width="*"/>
                        <DataGridTextColumn Header="Package ID" Binding="{Binding Id}" Width="2*"/>
                        <DataGridTextColumn Header="Source" Binding="{Binding Source}" Width="*"/>
                    </DataGrid.Columns>
                </DataGrid>
            </TabItem>
            <TabItem Header="Update history">
                <Grid>
                    <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <DataGrid x:Name="HistoryGrid" Grid.Row="0" AutoGenerateColumns="False" IsReadOnly="True" SelectionMode="Extended"
                              SelectionUnit="FullRow" GridLinesVisibility="None" HeadersVisibility="Column" RowHeaderWidth="0"
                              Background="White" BorderThickness="0" AlternatingRowBackground="#FAFBFD">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="When" Binding="{Binding When}" Width="1.2*"/>
                            <DataGridTextColumn Header="Application" Binding="{Binding Name}" Width="2*"/>
                            <DataGridTextColumn Header="Previous" Binding="{Binding InstalledVersion}" Width="*"/>
                            <DataGridTextColumn Header="Target" Binding="{Binding TargetVersion}" Width="*"/>
                            <DataGridTextColumn Header="Result" Binding="{Binding Result}" Width="*"/>
                            <DataGridTextColumn Header="Exit code" Binding="{Binding ExitCode}" Width="0.7*"/>
                            <DataGridTextColumn Header="Package ID" Binding="{Binding Id}" Width="2*"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    <Border Grid.Row="1" Background="#F8FAFC" BorderBrush="#E3E8F0" BorderThickness="0,1,0,0" Padding="12">
                        <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <TextBlock x:Name="HistorySummaryText" Text="No update attempts recorded." Foreground="#667085" VerticalAlignment="Center"/>
                            <StackPanel Grid.Column="1" Orientation="Horizontal">
                                <Button x:Name="OpenLogsButton" Content="Open logs"/>
                                <Button x:Name="ClearHistoryButton" Content="Clear history" Margin="0"/>
                            </StackPanel>
                        </Grid>
                    </Border>
                </Grid>
            </TabItem>
        </TabControl>

        <Border Grid.Row="3" Background="White" BorderBrush="#DFE4EC" BorderThickness="0,1,0,0" Padding="20,10">
            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <ProgressBar x:Name="BusyBar" Width="100" Height="5" IsIndeterminate="True" Visibility="Collapsed" VerticalAlignment="Center" Margin="0,0,12,0"/>
                <TextBlock x:Name="StatusText" Grid.Column="1" Text="Ready" Foreground="#667085" VerticalAlignment="Center"/>
                <TextBlock x:Name="VersionText" Grid.Column="2" Text="" Foreground="#98A2B3" VerticalAlignment="Center"/>
            </Grid>
        </Border>
    </Grid>
</Window>
'@

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$controlNames = @(
    'UpdateCountText', 'InstalledCountText', 'RefreshButton', 'ExportButton', 'ScheduleButton', 'SilentCheckBox',
    'SearchBox', 'UpdatesGrid', 'InstalledGrid', 'HistoryGrid', 'HistorySummaryText', 'OpenLogsButton', 'ClearHistoryButton', 'UpgradeSelectedButton', 'UpgradeAllButton',
    'BusyBar', 'StatusText', 'VersionText', 'MainTabs'
)
foreach ($name in $controlNames) {
    Set-Variable -Name $name -Value $window.FindName($name) -Scope Script
}

$script:Inventory = $null
$script:CurrentJob = $null
$script:UpdateView = $null
$script:InstalledView = $null
$script:HistoryView = $null
$script:PendingUpgradeInfo = @{}

function Get-ItemValue {
    param($Item, [string] $Name, $Default = '')
    if ($null -ne $Item -and $Item.PSObject.Properties[$Name]) { return $Item.PSObject.Properties[$Name].Value }
    return $Default
}

function Update-HistoryView {
    $history = @(
        foreach ($record in @(Get-WingetHistory)) {
            $timestamp = [string](Get-ItemValue $record 'Timestamp')
            $when = $timestamp
            $parsedTimestamp = [datetime]::MinValue
            if ([datetime]::TryParse($timestamp, [ref]$parsedTimestamp)) { $when = $parsedTimestamp.ToString('g') }
            [pscustomobject]@{
                Timestamp        = $timestamp
                When             = $when
                Name             = Get-ItemValue $record 'Name'
                Id               = Get-ItemValue $record 'Id'
                InstalledVersion = Get-ItemValue $record 'InstalledVersion'
                TargetVersion    = Get-ItemValue $record 'TargetVersion'
                Result           = Get-ItemValue $record 'Result'
                ExitCode         = Get-ItemValue $record 'ExitCode'
                LogFile          = Get-ItemValue $record 'LogFile'
            }
        }
    )
    $HistoryGrid.ItemsSource = $history
    $script:HistoryView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($HistoryGrid.ItemsSource)
    $HistorySummaryText.Text = if ($history.Count -eq 0) { 'No update attempts recorded.' } else { "$($history.Count) update attempt(s) recorded." }
    $ClearHistoryButton.IsEnabled = ($history.Count -gt 0)
}

function Update-ScheduleButton {
    $schedule = Get-WingetSchedule
    $ScheduleButton.Content = if ($schedule.Frequency -eq 'Disabled') {
        'Schedule scans'
    }
    elseif ($schedule.Frequency -eq 'Weekly') {
        "Weekly: $($schedule.DayOfWeek) $($schedule.Time)"
    }
    else {
        "Daily: $($schedule.Time)"
    }
}

function Set-BusyState {
    param([bool] $Busy, [string] $Message)
    $RefreshButton.IsEnabled = -not $Busy
    $ScheduleButton.IsEnabled = -not $Busy
    $ExportButton.IsEnabled = (-not $Busy -and $null -ne $script:Inventory)
    $OpenLogsButton.IsEnabled = -not $Busy
    $ClearHistoryButton.IsEnabled = (-not $Busy -and @($HistoryGrid.ItemsSource).Count -gt 0)
    $UpgradeSelectedButton.IsEnabled = (-not $Busy -and $UpdatesGrid.SelectedItems.Count -gt 0)
    $UpgradeAllButton.IsEnabled = (-not $Busy -and $null -ne $script:Inventory -and @($script:Inventory.Updates).Count -gt 0)
    $BusyBar.Visibility = if ($Busy) { 'Visible' } else { 'Collapsed' }
    $StatusText.Text = $Message
}

function Set-Inventory {
    param($Inventory)
    $script:Inventory = $Inventory
    $updates = @($Inventory.Updates)
    $installed = @($Inventory.Installed)
    $UpdatesGrid.ItemsSource = $updates
    $InstalledGrid.ItemsSource = $installed
    $UpdateCountText.Text = $updates.Count.ToString()
    $InstalledCountText.Text = $installed.Count.ToString()
    $VersionText.Text = if ($Inventory.Winget) { "Winget $($Inventory.Winget)" } else { '' }
    Update-HistoryView

    $script:UpdateView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($UpdatesGrid.ItemsSource)
    $script:InstalledView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($InstalledGrid.ItemsSource)
    $filter = [Predicate[object]] {
        param($item)
        $term = $SearchBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($term)) { return $true }
        return ([string](Get-ItemValue $item 'Name') -like "*$term*" -or [string](Get-ItemValue $item 'Id') -like "*$term*" -or [string](Get-ItemValue $item 'InstalledVersion') -like "*$term*" -or [string](Get-ItemValue $item 'AvailableVersion') -like "*$term*" -or [string](Get-ItemValue $item 'Result') -like "*$term*")
    }
    $script:UpdateView.Filter = $filter
    $script:InstalledView.Filter = $filter
    if ($script:HistoryView) { $script:HistoryView.Filter = $filter }

    $checked = [datetime] $Inventory.CheckedAt
    Set-BusyState -Busy $false -Message ("Last checked {0}" -f $checked.ToString('g'))
}

function Show-ScheduleDialog {
    [xml] $dialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Scheduled update scans" Width="520" Height="390" ResizeMode="NoResize" WindowStartupLocation="CenterOwner"
        Background="#F8FAFC" FontFamily="Segoe UI" ShowInTaskbar="False">
    <Grid Margin="24">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <TextBlock Text="Background update checks" FontSize="21" FontWeight="SemiBold" Foreground="#172033"/>
        <TextBlock Grid.Row="1" Margin="0,8,0,18" Foreground="#667085" TextWrapping="Wrap"
                   Text="Create a current-user Windows task that checks for updates and shows a notification. Scheduled scans never install updates."/>
        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions><ColumnDefinition Width="140"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <TextBlock Text="Frequency" VerticalAlignment="Center" FontWeight="SemiBold"/>
            <ComboBox x:Name="FrequencyBox" Grid.Column="1" Height="32">
                <ComboBoxItem Content="Disabled"/><ComboBoxItem Content="Daily"/><ComboBoxItem Content="Weekly"/>
            </ComboBox>
        </Grid>
        <Grid Grid.Row="3" Margin="0,12,0,0">
            <Grid.ColumnDefinitions><ColumnDefinition Width="140"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <TextBlock Text="Time (24-hour)" VerticalAlignment="Center" FontWeight="SemiBold"/>
            <TextBox x:Name="TimeBox" Grid.Column="1" Height="32" Padding="8,5"/>
        </Grid>
        <Grid Grid.Row="4" Margin="0,12,0,0">
            <Grid.ColumnDefinitions><ColumnDefinition Width="140"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <TextBlock Text="Day" VerticalAlignment="Center" FontWeight="SemiBold"/>
            <ComboBox x:Name="DayBox" Grid.Column="1" Height="32">
                <ComboBoxItem Content="Monday"/><ComboBoxItem Content="Tuesday"/><ComboBoxItem Content="Wednesday"/>
                <ComboBoxItem Content="Thursday"/><ComboBoxItem Content="Friday"/><ComboBoxItem Content="Saturday"/><ComboBoxItem Content="Sunday"/>
            </ComboBox>
        </Grid>
        <StackPanel Grid.Row="5">
            <TextBlock x:Name="ScheduleErrorText" Margin="0,14,0,0" Foreground="#B42318" TextWrapping="Wrap"/>
            <TextBlock Margin="0,10,0,0" Foreground="#667085" TextWrapping="Wrap"
                       Text="Notifications require the user to be signed in. Windows may require administrator approval to create or change the scheduled task."/>
        </StackPanel>
        <StackPanel Grid.Row="6" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
            <Button x:Name="CancelButton" Content="Cancel" Padding="15,8" Margin="0,0,8,0" Background="#E8EEF9" BorderThickness="0"/>
            <Button x:Name="SaveButton" Content="Save schedule" Padding="15,8" Background="#2563EB" Foreground="White" BorderThickness="0"/>
        </StackPanel>
    </Grid>
</Window>
'@
    $reader = [System.Xml.XmlNodeReader]::new($dialogXaml)
    $dialog = [Windows.Markup.XamlReader]::Load($reader)
    $dialog.Owner = $window
    $frequencyBox = $dialog.FindName('FrequencyBox')
    $timeBox = $dialog.FindName('TimeBox')
    $dayBox = $dialog.FindName('DayBox')
    $errorText = $dialog.FindName('ScheduleErrorText')
    $saveButton = $dialog.FindName('SaveButton')
    $cancelButton = $dialog.FindName('CancelButton')
    $schedule = Get-WingetSchedule

    foreach ($item in $frequencyBox.Items) {
        if ($item.Content -eq $schedule.Frequency) { $frequencyBox.SelectedItem = $item; break }
    }
    foreach ($item in $dayBox.Items) {
        if ($item.Content -eq $schedule.DayOfWeek) { $dayBox.SelectedItem = $item; break }
    }
    if ($frequencyBox.SelectedIndex -lt 0) { $frequencyBox.SelectedIndex = 0 }
    if ($dayBox.SelectedIndex -lt 0) { $dayBox.SelectedIndex = 0 }
    $timeBox.Text = [string]$schedule.Time
    $dayBox.IsEnabled = ($frequencyBox.SelectedItem.Content -eq 'Weekly')

    $frequencyBox.Add_SelectionChanged({ $dayBox.IsEnabled = ($frequencyBox.SelectedItem.Content -eq 'Weekly') })
    $cancelButton.Add_Click({ $dialog.Close() })
    $saveButton.Add_Click({
        $frequency = [string]$frequencyBox.SelectedItem.Content
        $day = [string]$dayBox.SelectedItem.Content
        $time = $timeBox.Text.Trim()
        $parsedTime = [datetime]::MinValue
        $validTime = [datetime]::TryParseExact($time, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedTime)
        if ($frequency -ne 'Disabled' -and -not $validTime) {
            $errorText.Text = 'Enter a valid 24-hour time in HH:mm format, for example 09:30.'
            return
        }
        if ($frequency -eq 'Disabled' -and -not $validTime) { $time = '09:00' }
        try {
            $scanScript = Join-Path $PSScriptRoot 'WingetScheduledScan.ps1'
            $null = Set-WingetScanSchedule -Frequency $frequency -Time $time -DayOfWeek $day -ScriptPath $scanScript
            $dialog.DialogResult = $true
        }
        catch {
            $errorText.Text = $_.Exception.Message
        }
    })
    return $dialog.ShowDialog()
}

function Write-UpgradeHistory {
    param([object[]] $Actions)

    foreach ($action in $Actions) {
        $package = $script:PendingUpgradeInfo[[string]$action.Id]
        $name = if ($package) { [string]$package.Name } else { [string]$action.Id }
        $installedVersion = if ($package) { [string]$package.InstalledVersion } else { '' }
        $targetVersion = if ($package) { [string]$package.AvailableVersion } else { '' }
        $logFile = ''
        if (-not $action.Succeeded) {
            $logFile = Write-WingetFailureLog -PackageId ([string]$action.Id) -ExitCode ([int]$action.ExitCode) -Command ([string]$action.Command) -Message ([string]$action.Message)
        }
        Add-WingetHistoryRecord -Record ([pscustomobject]@{
            Timestamp        = Get-Date -Format 'o'
            Name             = $name
            Id               = [string]$action.Id
            InstalledVersion = $installedVersion
            TargetVersion    = $targetVersion
            Result           = if ($action.Succeeded) { 'Succeeded' } else { 'Failed' }
            ExitCode         = [int]$action.ExitCode
            LogFile          = $logFile
        })
    }
    $script:PendingUpgradeInfo = @{}
    Update-HistoryView
}

function Start-ToolJob {
    param(
        [ValidateSet('Refresh', 'UpgradeSelected', 'UpgradeAll')][string] $Operation,
        [string[]] $Ids = @()
    )

    if ($script:CurrentJob) { return }
    $silent = [bool] $SilentCheckBox.IsChecked
    $script:PendingUpgradeInfo = @{}
    foreach ($id in $Ids) {
        $package = @($script:Inventory.Updates | Where-Object { $_.Id -eq $id } | Select-Object -First 1)
        if ($package.Count -gt 0) { $script:PendingUpgradeInfo[$id] = $package[0] }
    }
    $message = switch ($Operation) {
        'Refresh' { 'Scanning installed applications and checking for updates...' }
        'UpgradeSelected' { "Upgrading $($Ids.Count) selected application(s)..." }
        'UpgradeAll' { 'Upgrading all available applications...' }
    }
    Set-BusyState -Busy $true -Message $message

    $script:CurrentJob = Start-Job -ArgumentList $modulePath, $Operation, $Ids, $silent -ScriptBlock {
        param($ModulePath, $OperationName, $PackageIds, $UseSilent)
        Import-Module $ModulePath -Force
        $actionResults = @()
        if ($OperationName -in @('UpgradeSelected', 'UpgradeAll')) {
            foreach ($packageId in $PackageIds) {
                $actionResults += Invoke-WingetUpgrade -Id $packageId -Silent:$UseSilent
            }
        }
        $inventory = Get-WingetInventory
        [pscustomobject]@{ Inventory = $inventory; ActionResults = $actionResults }
    }
}

function Complete-ToolJob {
    if (-not $script:CurrentJob -or $script:CurrentJob.State -notin @('Completed', 'Failed', 'Stopped')) { return }
    $job = $script:CurrentJob
    $script:CurrentJob = $null
    try {
        if ($job.State -ne 'Completed') {
            $reason = if ($job.ChildJobs[0].JobStateInfo.Reason) { $job.ChildJobs[0].JobStateInfo.Reason.Message } else { 'The background operation failed.' }
            throw $reason
        }
        $result = Receive-Job -Job $job -ErrorAction Stop | Select-Object -Last 1
        if (-not $result -or -not $result.Inventory) { throw 'Winget returned no inventory data.' }
        Set-Inventory -Inventory $result.Inventory

        $actions = @($result.ActionResults)
        if ($actions.Count -gt 0) {
            Write-UpgradeHistory -Actions $actions
            $failed = @($actions | Where-Object { -not $_.Succeeded })
            if ($failed.Count -eq 0) {
                [System.Windows.MessageBox]::Show('The upgrade operation completed. The application list has been refreshed.', 'Upgrade complete', 'OK', 'Information') | Out-Null
            }
            else {
                $details = ($failed | ForEach-Object { "$($_.Id) (exit code $($_.ExitCode))" }) -join "`n"
                [System.Windows.MessageBox]::Show("Some upgrades did not complete:`n`n$details`n`nTry running this tool as Administrator or clear the silent option. Detailed output is available under Open logs.", 'Upgrade results', 'OK', 'Warning') | Out-Null
            }
        }
    }
    catch {
        Set-BusyState -Busy $false -Message 'The operation did not complete.'
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Winget Update Center', 'OK', 'Error') | Out-Null
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(350)
$timer.Add_Tick({ Complete-ToolJob })
$timer.Start()

$RefreshButton.Add_Click({ Start-ToolJob -Operation Refresh })
$ScheduleButton.Add_Click({
    if (Show-ScheduleDialog) {
        Update-ScheduleButton
        $StatusText.Text = 'Background scan schedule updated.'
    }
})
$UpdatesGrid.Add_SelectionChanged({
    $UpgradeSelectedButton.IsEnabled = ($null -eq $script:CurrentJob -and $UpdatesGrid.SelectedItems.Count -gt 0)
})
$SearchBox.Add_TextChanged({
    if ($script:UpdateView) { $script:UpdateView.Refresh() }
    if ($script:InstalledView) { $script:InstalledView.Refresh() }
    if ($script:HistoryView) { $script:HistoryView.Refresh() }
})
$UpgradeSelectedButton.Add_Click({
    $ids = @($UpdatesGrid.SelectedItems | ForEach-Object { $_.Id } | Select-Object -Unique)
    if ($ids.Count -gt 0) { Start-ToolJob -Operation UpgradeSelected -Ids $ids }
})
$UpgradeAllButton.Add_Click({
    $count = @($script:Inventory.Updates).Count
    $answer = [System.Windows.MessageBox]::Show("Upgrade all $count available applications?`n`nInstallers may request administrator approval or briefly open their own windows.", 'Confirm upgrades', 'YesNo', 'Question')
    if ($answer -eq 'Yes') {
        $ids = @($script:Inventory.Updates | ForEach-Object { $_.Id } | Select-Object -Unique)
        Start-ToolJob -Operation UpgradeAll -Ids $ids
    }
})
$OpenLogsButton.Add_Click({
    $logDirectory = Get-WingetLogDirectory
    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $logDirectory)
})
$ClearHistoryButton.Add_Click({
    $answer = [System.Windows.MessageBox]::Show('Clear the update-attempt history? Failure log files will be retained.', 'Clear update history', 'YesNo', 'Question')
    if ($answer -eq 'Yes') {
        Clear-WingetHistory
        Update-HistoryView
        $StatusText.Text = 'Update history cleared.'
    }
})
$HistoryGrid.Add_MouseDoubleClick({
    $record = $HistoryGrid.SelectedItem
    if (-not $record -or [string]::IsNullOrWhiteSpace([string]$record.LogFile) -or -not (Test-Path -LiteralPath $record.LogFile)) { return }
    Start-Process -FilePath 'notepad.exe' -ArgumentList ('"{0}"' -f $record.LogFile)
})
$ExportButton.Add_Click({
    $dialog = [Microsoft.Win32.SaveFileDialog]::new()
    $dialog.Filter = 'CSV files (*.csv)|*.csv'
    $dialog.FileName = 'winget-inventory-{0}.csv' -f (Get-Date -Format 'yyyy-MM-dd-HHmm')
    if ($dialog.ShowDialog($window)) {
        $rows = switch ($MainTabs.SelectedIndex) {
            0 { @($script:Inventory.Updates) }
            1 { @($script:Inventory.Installed) }
            default { @($HistoryGrid.ItemsSource) }
        }
        if ($MainTabs.SelectedIndex -eq 2) {
            $rows | Select-Object Timestamp, Name, Id, InstalledVersion, TargetVersion, Result, ExitCode, LogFile | Export-Csv -Path $dialog.FileName -NoTypeInformation -Encoding UTF8
        }
        else {
            $rows | Select-Object Name, Id, InstalledVersion, AvailableVersion, Source | Export-Csv -Path $dialog.FileName -NoTypeInformation -Encoding UTF8
        }
        $StatusText.Text = "Exported $($rows.Count) row(s) to $($dialog.FileName)"
    }
})
$window.Add_Closing({
    $timer.Stop()
    if ($script:CurrentJob) {
        Stop-Job -Job $script:CurrentJob -ErrorAction SilentlyContinue
        Remove-Job -Job $script:CurrentJob -Force -ErrorAction SilentlyContinue
    }
})
$window.Add_ContentRendered({
    Update-ScheduleButton
    Update-HistoryView
    Start-ToolJob -Operation Refresh
})

$window.ShowDialog() | Out-Null
