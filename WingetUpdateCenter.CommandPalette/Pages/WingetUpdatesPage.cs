using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace WingetUpdateCenter.CommandPalette;

internal sealed partial class WingetUpdatesPage : ListPage
{
    private readonly Lock _stateLock = new();
    private readonly WingetService _service;
    private IListItem[] _items;
    private WingetPackage[] _availableUpdates = [];
    private bool _hasStarted;
    private bool _isBusy;

    public WingetUpdatesPage(WingetService service)
    {
        _service = service;
        Icon = AccentVisuals.DockIcon();
        Title = "Winget Update Center";
        Name = "Open";
        PlaceholderText = "Search installed apps by name, ID, or version";
        ShowDetails = true;
        _items = [CreateStatusItem("Loading installed apps...", "Winget is checking this computer")];
    }

    public override IListItem[] GetItems()
    {
        EnsureLoaded();
        lock (_stateLock)
        {
            return _items;
        }
    }

    internal void Refresh()
    {
        lock (_stateLock)
        {
            if (_isBusy)
            {
                return;
            }

            _hasStarted = true;
            _isBusy = true;
            _items = [CreateStatusItem("Checking for updates...", "Reading the installed app inventory")];
        }

        RaiseItemsChanged();
        StatusMessage progress = ShowProgress("Checking installed apps and available updates...");
        _ = RefreshCoreAsync(progress);
    }

    internal void Upgrade(WingetPackage package)
    {
        if (!TryBeginOperation($"Updating {package.Name}...", $"{package.InstalledVersion} to {package.AvailableVersion}"))
        {
            new ToastStatusMessage("Winget is already busy").Show();
            return;
        }

        StatusMessage progress = ShowProgress($"Updating {package.Name}...");
        _ = UpgradeCoreAsync(package, progress);
    }

    internal void UpgradeAll()
    {
        int count = 0;
        bool startWithoutInventory = false;
        bool isBusy = false;
        lock (_stateLock)
        {
            if (_isBusy)
            {
                isBusy = true;
            }
            else if (!_hasStarted)
            {
                _hasStarted = true;
                _isBusy = true;
                _items = [CreateStatusItem("Checking and updating apps...", "Winget will install every available update")];
                startWithoutInventory = true;
            }
            else
            {
                count = _availableUpdates.Length;
            }
        }

        if (isBusy)
        {
            new ToastStatusMessage("Winget is already busy").Show();
            return;
        }

        if (startWithoutInventory)
        {
            RaiseItemsChanged();
            StatusMessage progress = ShowProgress("Checking and updating all apps...");
            _ = UpgradeAllCoreAsync(null, progress);
            return;
        }

        if (count == 0)
        {
            new ToastStatusMessage("No app updates are currently available").Show();
            return;
        }

        if (!TryBeginOperation("Updating all apps...", $"Installing {count} available update{(count == 1 ? string.Empty : "s")}"))
        {
            new ToastStatusMessage("Winget is already busy").Show();
            return;
        }

        StatusMessage updateProgress = ShowProgress($"Updating {count} app{(count == 1 ? string.Empty : "s")}...");
        _ = UpgradeAllCoreAsync(count, updateProgress);
    }

    private void EnsureLoaded()
    {
        bool shouldStart;
        lock (_stateLock)
        {
            shouldStart = !_hasStarted;
            if (shouldStart)
            {
                _hasStarted = true;
                _isBusy = true;
            }
        }

        if (shouldStart)
        {
            StatusMessage progress = ShowProgress("Loading installed apps and available updates...");
            _ = RefreshCoreAsync(progress);
        }
    }

    private bool TryBeginOperation(string title, string subtitle)
    {
        lock (_stateLock)
        {
            if (_isBusy)
            {
                return false;
            }

            _isBusy = true;
            _items = [CreateStatusItem(title, subtitle)];
        }

        RaiseItemsChanged();
        return true;
    }

    private async Task RefreshCoreAsync(StatusMessage progress)
    {
        try
        {
            WingetInventory inventory = await _service.GetInventoryAsync().ConfigureAwait(false);
            ApplyInventory(inventory);
        }
        catch (Exception exception)
        {
            ShowError("Could not check installed apps", exception);
        }
        finally
        {
            HideProgress(progress);
        }
    }

    private async Task UpgradeCoreAsync(WingetPackage package, StatusMessage progress)
    {
        try
        {
            WingetCommandResult result = await _service.UpgradeAsync(package).ConfigureAwait(false);
            if (!result.Succeeded)
            {
                throw new InvalidOperationException(GetFailureMessage(result));
            }

            new ToastStatusMessage($"Updated {package.Name}").Show();
            await RefreshAfterUpgradeAsync().ConfigureAwait(false);
        }
        catch (Exception exception)
        {
            ShowError($"Could not update {package.Name}", exception);
        }
        finally
        {
            HideProgress(progress);
        }
    }

    private async Task UpgradeAllCoreAsync(int? count, StatusMessage progress)
    {
        try
        {
            WingetCommandResult result = await _service.UpgradeAllAsync().ConfigureAwait(false);
            if (!result.Succeeded)
            {
                throw new InvalidOperationException(GetFailureMessage(result));
            }

            string message = count.HasValue
                ? $"Finished updating {count} app{(count == 1 ? string.Empty : "s")}"
                : "Finished checking and updating apps";
            new ToastStatusMessage(message).Show();
            await RefreshAfterUpgradeAsync().ConfigureAwait(false);
        }
        catch (Exception exception)
        {
            ShowError("Could not update all apps", exception);
        }
        finally
        {
            HideProgress(progress);
        }
    }

    private async Task RefreshAfterUpgradeAsync()
    {
        WingetInventory inventory = await _service.GetInventoryAsync().ConfigureAwait(false);
        ApplyInventory(inventory);
    }

    private void ApplyInventory(WingetInventory inventory)
    {
        IListItem[] items = CreateInventoryItems(inventory);
        lock (_stateLock)
        {
            _availableUpdates = inventory.Installed.Where(package => package.HasUpdate).ToArray();
            _items = items;
            _isBusy = false;
        }

        RaiseItemsChanged(inventory.Installed.Count);
    }

    private IListItem[] CreateInventoryItems(WingetInventory inventory)
    {
        List<IListItem> items = [];
        WingetPackage[] updates = inventory.Installed.Where(package => package.HasUpdate).ToArray();

        items.Add(new ListItem(new RefreshCommand(this))
        {
            Title = $"Checked {inventory.CheckedAt:t}",
            Subtitle = $"{inventory.Installed.Count} installed apps; {updates.Length} update{(updates.Length == 1 ? string.Empty : "s")} available - select to refresh",
            Icon = AccentVisuals.CheckedIcon(),
            Tags = [AccentVisuals.CheckedTag()],
        });

        if (updates.Length > 0)
        {
            items.Add(new ListItem(new UpgradeAllCommand(this))
            {
                Title = $"Update all {updates.Length} apps",
                Subtitle = "Install every available update with Winget",
                Icon = AccentVisuals.UpdateIcon(),
                Tags = [AccentVisuals.UpdateTag("Update all")],
            });
        }

        foreach (WingetPackage package in inventory.Installed)
        {
            items.Add(CreatePackageItem(package));
        }

        return items.ToArray();
    }

    private ListItem CreatePackageItem(WingetPackage package)
    {
        if (package.HasUpdate)
        {
            UpgradePackageCommand command = new(this, package);
            return new ListItem(command)
            {
                Title = package.Name,
                Subtitle = $"Update {package.InstalledVersion} -> {package.AvailableVersion} | {package.Id} | {package.Source}",
                Icon = AccentVisuals.UpdateIcon(),
                Tags = [AccentVisuals.UpdateTag()],
            };
        }

        return new ListItem(new NoOpCommand())
        {
            Title = package.Name,
            Subtitle = $"Current: {package.InstalledVersion} | {package.Id} | {package.Source}",
            Icon = AccentVisuals.UpdatedIcon(),
            Tags = [AccentVisuals.UpdatedTag()],
        };
    }

    private void ShowError(string title, Exception exception)
    {
        string detail = exception.Message.Trim();
        lock (_stateLock)
        {
            _isBusy = false;
            _items =
            [
                new ListItem(new RefreshCommand(this))
                {
                    Title = title,
                    Subtitle = detail,
                    Icon = new IconInfo("\uEA39"),
                },
            ];
        }

        RaiseItemsChanged();
        new ToastStatusMessage(title).Show();
    }

    private static ListItem CreateStatusItem(string title, string subtitle) => new ListItem(new NoOpCommand())
    {
        Title = title,
        Subtitle = subtitle,
        Icon = new IconInfo("\uE895"),
    };

    private StatusMessage ShowProgress(string message)
    {
        IsLoading = true;
        StatusMessage status = new()
        {
            Message = message,
            State = MessageState.Info,
            Progress = new ProgressState
            {
                IsIndeterminate = true,
            },
        };

        ExtensionHost.ShowStatus(status, StatusContext.Page);
        return status;
    }

    private void HideProgress(StatusMessage status)
    {
        IsLoading = false;
        ExtensionHost.HideStatus(status);
    }

    private static string GetFailureMessage(WingetCommandResult result)
    {
        string output = result.CombinedOutput.Trim();
        if (string.IsNullOrWhiteSpace(output))
        {
            return $"Winget exited with code {result.ExitCode}.";
        }

        return output.Length <= 600 ? output : output[..600];
    }
}
