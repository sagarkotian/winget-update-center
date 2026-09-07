using Microsoft.CommandPalette.Extensions;
using Shmuelie.WinRTServer.CsWinRT;

namespace WingetUpdateCenter.CommandPalette;

public static class Program
{
    [MTAThread]
    public static void Main(string[] args)
    {
        if (args.Length == 0 || args[0] != "-RegisterProcessAsComServer")
        {
            return;
        }

        global::Shmuelie.WinRTServer.ComServer server = new();
        using ManualResetEvent extensionDisposedEvent = new(false);
        WingetUpdateCenterExtension extension = new(extensionDisposedEvent);

        server.RegisterClass<WingetUpdateCenterExtension, IExtension>(() => extension);
        server.Start();
        extensionDisposedEvent.WaitOne();
        server.Stop();
        server.UnsafeDispose();
    }
}
