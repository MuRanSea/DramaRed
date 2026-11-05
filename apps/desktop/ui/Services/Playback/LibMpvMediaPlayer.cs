using System.Runtime.InteropServices;

namespace DramaRed.UI.Services.Playback;

/// <summary>
/// Best-effort libmpv host via P/Invoke. Resolves:
/// - Linux: libmpv.so.2 / libmpv.so
/// - macOS: libmpv.dylib
/// - Windows (optional): libmpv-2.dll / mpv-2.dll next to the executable or on PATH
/// </summary>
public sealed class LibMpvMediaPlayer : IMediaPlayer
{
    public bool AutoNext { get; set; } = true;
    public double Rate { get; set; } = 1.0;
    public TimeSpan? StopAfter { get; set; }

    private IntPtr _handle;
    private readonly string _libraryPath;

    private LibMpvMediaPlayer(string libraryPath)
    {
        _libraryPath = libraryPath;
        // Scaffold: do not fully wire mpv_create yet; prove library load + API shape.
        // Full render surface lands in a follow-up.
        if (!NativeLibrary.TryLoad(libraryPath, out _))
        {
            throw new DllNotFoundException($"Failed to load mpv native library: {libraryPath}");
        }
    }

    public static bool TryCreate(out IMediaPlayer player, out string detail)
    {
        foreach (var candidate in CandidateLibraries())
        {
            if (NativeLibrary.TryLoad(candidate, out var lib))
            {
                NativeLibrary.Free(lib);
                try
                {
                    player = new LibMpvMediaPlayer(candidate);
                    detail = $"loaded {candidate}";
                    return true;
                }
                catch (Exception ex)
                {
                    detail = ex.Message;
                    player = new NullMediaPlayer();
                    return false;
                }
            }
        }

        detail = "no libmpv candidate found on this OS";
        player = new NullMediaPlayer();
        return false;
    }

    private static IEnumerable<string> CandidateLibraries()
    {
        if (OperatingSystem.IsLinux())
        {
            yield return "libmpv.so.2";
            yield return "libmpv.so";
            yield return "/usr/lib/x86_64-linux-gnu/libmpv.so.2";
            yield return "/usr/lib/libmpv.so.2";
        }
        else if (OperatingSystem.IsMacOS())
        {
            yield return "libmpv.dylib";
            yield return "/opt/homebrew/lib/libmpv.dylib";
            yield return "/usr/local/lib/libmpv.dylib";
        }
        else if (OperatingSystem.IsWindows())
        {
            var baseDir = AppContext.BaseDirectory;
            yield return Path.Combine(baseDir, "libmpv-2.dll");
            yield return Path.Combine(baseDir, "mpv-2.dll");
            yield return "libmpv-2.dll";
            yield return "mpv-2.dll";
        }
    }

    public Task OpenAsync(string url, string? contentKeyHex = null, CancellationToken ct = default)
    {
        _ = url;
        _ = contentKeyHex;
        // TODO: mpv_create / mpv_command_async loadfile; set decryption_key when present.
        throw new NotImplementedException($"LibMpvMediaPlayer.OpenAsync scaffold — library probed at {_libraryPath}");
    }

    public Task PauseAsync(CancellationToken ct = default) => Task.CompletedTask;
    public Task ResumeAsync(CancellationToken ct = default) => Task.CompletedTask;
    public Task StopAsync(CancellationToken ct = default) => Task.CompletedTask;

    public void Dispose()
    {
        if (_handle != IntPtr.Zero)
        {
            _handle = IntPtr.Zero;
        }
    }
}
