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

    public string? LastError { get; private set; }

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
        LastError = null;
        if (await client.HealthAsync(ct)) return true;

        DaemonPath = FindDaemon();
        if (DaemonPath == null)
        {
            LastError = "未找到 drama-daemon，请把它和 DramaRed.UI 放在同一目录";
            return false;
        }

        try
        {
            var workDir = Path.GetDirectoryName(DaemonPath) ?? AppContext.BaseDirectory;
            var dataDir = Path.Combine(workDir, "data");
            Directory.CreateDirectory(dataDir);

            // Prefer device profile next to the exe so Windows zip is self-contained.
            var deviceBeside = Path.Combine(workDir, "anonymous.json");
            var deviceArg = File.Exists(deviceBeside) ? deviceBeside : "anonymous.json";

            _process = Process.Start(new ProcessStartInfo
            {
                FileName = DaemonPath,
                Arguments = $"-addr 127.0.0.1:17890 -data \"{dataDir}\" -device \"{deviceArg}\"",
                WorkingDirectory = workDir,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
            });
        }
        catch (Exception ex)
        {
            LastError = $"无法启动 daemon：{ex.Message}";
            return false;
        }

        // Wait up to ~8s for health (first openhongguo init can be slow on cold start).
        for (var i = 0; i < 32; i++)
        {
            ct.ThrowIfCancellationRequested();
            if (_process is { HasExited: true })
            {
                LastError = $"daemon 启动后立即退出（exit={_process.ExitCode}）";
                return false;
            }
            if (await client.HealthAsync(ct)) return true;
            await Task.Delay(250, ct);
        }

        LastError = "daemon 已启动但健康检查超时";
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
