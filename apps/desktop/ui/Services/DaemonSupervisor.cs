using System.Diagnostics;

namespace DramaRed.UI.Services;

/// <summary>
/// Starts a sibling <c>drama-daemon</c> process when the local API is down.
/// Used so a Windows zip can be launched from DramaRed.UI.exe alone.
/// </summary>
public sealed class DaemonSupervisor : IDisposable
{
    private Process? _process;

    public bool StartedByUs => _process is { HasExited: false };

    public string? DaemonPath { get; private set; }

    public static string? FindDaemon()
    {
        var baseDir = AppContext.BaseDirectory;
        var names = OperatingSystem.IsWindows()
            ? new[] { "drama-daemon.exe" }
            : new[] { "drama-daemon", "drama-daemon.exe" };

        foreach (var name in names)
        {
            var beside = Path.Combine(baseDir, name);
            if (File.Exists(beside)) return beside;
        }

        // Dev tree: apps/desktop/ui → ../daemon
        var dev = Path.GetFullPath(Path.Combine(baseDir, "..", "..", "..", "..", "daemon"));
        foreach (var name in names)
        {
            var candidate = Path.Combine(dev, name);
            if (File.Exists(candidate)) return candidate;
        }

        return null;
    }

    public async Task<bool> EnsureRunningAsync(DaemonClient client, CancellationToken ct = default)
    {
        if (await client.HealthAsync(ct)) return true;

        DaemonPath = FindDaemon();
        if (DaemonPath == null) return false;

        try
        {
            var workDir = Path.GetDirectoryName(DaemonPath) ?? AppContext.BaseDirectory;
            var dataDir = Path.Combine(workDir, "data");
            Directory.CreateDirectory(dataDir);

            _process = Process.Start(new ProcessStartInfo
            {
                FileName = DaemonPath,
                Arguments = $"-addr 127.0.0.1:17890 -data \"{dataDir}\"",
                WorkingDirectory = workDir,
                UseShellExecute = false,
                CreateNoWindow = true,
            });
        }
        catch
        {
            return false;
        }

        for (var i = 0; i < 20; i++)
        {
            ct.ThrowIfCancellationRequested();
            if (await client.HealthAsync(ct)) return true;
            await Task.Delay(250, ct);
        }

        return await client.HealthAsync(ct);
    }

    public void Dispose()
    {
        if (_process is { HasExited: false })
        {
            try { _process.Kill(entireProcessTree: true); } catch { /* ignore */ }
        }
        _process?.Dispose();
        _process = null;
    }
}
