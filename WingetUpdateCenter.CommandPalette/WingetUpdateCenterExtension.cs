using System.Runtime.InteropServices;
using Microsoft.CommandPalette.Extensions;

namespace WingetUpdateCenter.CommandPalette;

[Guid("426EBE4F-275E-48E5-9944-F2A6D217B326")]
public sealed partial class WingetUpdateCenterExtension : IExtension, IDisposable
{
    private readonly ManualResetEvent _extensionDisposedEvent;
    private readonly WingetUpdateCommandsProvider _provider = new();

    public WingetUpdateCenterExtension(ManualResetEvent extensionDisposedEvent)
    {
        _extensionDisposedEvent = extensionDisposedEvent;
    }

    public object? GetProvider(ProviderType providerType) => providerType switch
    {
        ProviderType.Commands => _provider,
        _ => null,
    };

    public void Dispose() => _extensionDisposedEvent.Set();
}
