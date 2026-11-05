using System.Runtime.InteropServices;
using System.Text;

namespace DramaRed.UI.Services.Playback;

/// <summary>
/// libmpv host via dynamic P/Invoke. Opens an external mpv video window on Linux
/// (vo=x11/gpu) when DISPLAY is set; falls back to vo=null (audio-only) otherwise.
/// </summary>
public sealed class LibMpvMediaPlayer : IMediaPlayer
{
    private const int MpvFormatString = 1;
    private const int MpvEventShutdown = 1;
    private const int MpvEventEndFile = 7;

    public bool AutoNext { get; set; } = true;
    public double Rate
    {
        get => _rate;
        set
        {
            _rate = value;
            if (_ctx != IntPtr.Zero)
            {
                SetPropertyString("speed", value.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture));
            }
        }
    }
    public TimeSpan? StopAfter { get; set; }

    public event Action? PlaybackEnded;

    private readonly string _libraryPath;
    private readonly IntPtr _lib;
    private IntPtr _ctx;
    private double _rate = 1.0;
    private bool _muted;
    private Thread? _eventThread;
    private volatile bool _running;
    private readonly object _gate = new();

    private delegate IntPtr MpvCreate();
    private delegate int MpvInitialize(IntPtr ctx);
    private delegate void MpvTerminateDestroy(IntPtr ctx);
    private delegate int MpvCommand(IntPtr ctx, IntPtr args);
    private delegate int MpvCommandString(IntPtr ctx, [MarshalAs(UnmanagedType.LPUTF8Str)] string args);
    private delegate int MpvSetOptionString(IntPtr ctx,
        [MarshalAs(UnmanagedType.LPUTF8Str)] string name,
        [MarshalAs(UnmanagedType.LPUTF8Str)] string data);
    private delegate int MpvSetPropertyString(IntPtr ctx,
        [MarshalAs(UnmanagedType.LPUTF8Str)] string name,
        [MarshalAs(UnmanagedType.LPUTF8Str)] string data);
    private delegate int MpvGetProperty(IntPtr ctx,
        [MarshalAs(UnmanagedType.LPUTF8Str)] string name,
        int format, out IntPtr data);
    private delegate void MpvFree(IntPtr data);
    private delegate IntPtr MpvWaitEvent(IntPtr ctx, double timeout);

    private readonly MpvCreate _mpvCreate;
    private readonly MpvInitialize _mpvInitialize;
    private readonly MpvTerminateDestroy _mpvTerminateDestroy;
    private readonly MpvCommand _mpvCommand;
    private readonly MpvCommandString _mpvCommandString;
    private readonly MpvSetOptionString _mpvSetOptionString;
    private readonly MpvSetPropertyString _mpvSetPropertyString;
    private readonly MpvGetProperty _mpvGetProperty;
    private readonly MpvFree _mpvFree;
    private readonly MpvWaitEvent _mpvWaitEvent;

    private LibMpvMediaPlayer(string libraryPath, IntPtr lib)
    {
        _libraryPath = libraryPath;
        _lib = lib;
        _mpvCreate = Load<MpvCreate>("mpv_create");
        _mpvInitialize = Load<MpvInitialize>("mpv_initialize");
        _mpvTerminateDestroy = Load<MpvTerminateDestroy>("mpv_terminate_destroy");
        _mpvCommand = Load<MpvCommand>("mpv_command");
        _mpvCommandString = Load<MpvCommandString>("mpv_command_string");
        _mpvSetOptionString = Load<MpvSetOptionString>("mpv_set_option_string");
        _mpvSetPropertyString = Load<MpvSetPropertyString>("mpv_set_property_string");
        _mpvGetProperty = Load<MpvGetProperty>("mpv_get_property");
        _mpvFree = Load<MpvFree>("mpv_free");
        _mpvWaitEvent = Load<MpvWaitEvent>("mpv_wait_event");

        _ctx = _mpvCreate();
        if (_ctx == IntPtr.Zero)
        {
            throw new InvalidOperationException("mpv_create failed");
        }

        // Prefer a real window when a display is available; else audio-only.
        var display = Environment.GetEnvironmentVariable("DISPLAY");
        if (!string.IsNullOrWhiteSpace(display))
        {
            // External window (issue #8 accepts 外接窗口).
            _ = _mpvSetOptionString(_ctx, "force-window", "yes");
            _ = _mpvSetOptionString(_ctx, "keep-open", "yes");
        }
        else
        {
            _ = _mpvSetOptionString(_ctx, "vo", "null");
            _ = _mpvSetOptionString(_ctx, "force-window", "no");
        }

        _ = _mpvSetOptionString(_ctx, "osc", "yes");
        _ = _mpvSetOptionString(_ctx, "input-default-bindings", "yes");
        _ = _mpvSetOptionString(_ctx, "input-vo-keyboard", "yes");

        var init = _mpvInitialize(_ctx);
        if (init < 0)
        {
            _mpvTerminateDestroy(_ctx);
            _ctx = IntPtr.Zero;
            throw new InvalidOperationException($"mpv_initialize failed: {init}");
        }

        _running = true;
        _eventThread = new Thread(EventLoop) { IsBackground = true, Name = "mpv-events" };
        _eventThread.Start();
    }

    public static bool TryCreate(out IMediaPlayer player, out string detail)
    {
        foreach (var candidate in CandidateLibraries())
        {
            if (!NativeLibrary.TryLoad(candidate, out var lib))
            {
                continue;
            }

            try
            {
                player = new LibMpvMediaPlayer(candidate, lib);
                detail = $"libmpv ready ({candidate})";
                return true;
            }
            catch (Exception ex)
            {
                NativeLibrary.Free(lib);
                detail = $"probe {candidate}: {ex.Message}";
                // try next candidate
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

    private T Load<T>(string name) where T : Delegate
    {
        var ptr = NativeLibrary.GetExport(_lib, name);
        return Marshal.GetDelegateForFunctionPointer<T>(ptr);
    }

    public Task OpenAsync(string url, string? contentKeyHex = null, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(url))
        {
            throw new ArgumentException("url required", nameof(url));
        }

        lock (_gate)
        {
            EnsureAlive();
            if (!string.IsNullOrWhiteSpace(contentKeyHex))
            {
                // Best-effort ClearKey / decryption_key for protected streams.
                _ = _mpvSetOptionString(_ctx, "demuxer-lavf-o", $"decryption_key={contentKeyHex}");
            }

            SetPropertyString("pause", "no");
            SetPropertyString("speed", _rate.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture));

            // mpv_command: loadfile <url> replace
            Command("loadfile", url, "replace");
        }

        return Task.CompletedTask;
    }

    public Task PauseAsync(CancellationToken ct = default)
    {
        lock (_gate)
        {
            EnsureAlive();
            SetPropertyString("pause", "yes");
        }
        return Task.CompletedTask;
    }

    public Task ResumeAsync(CancellationToken ct = default)
    {
        lock (_gate)
        {
            EnsureAlive();
            SetPropertyString("pause", "no");
        }
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken ct = default)
    {
        lock (_gate)
        {
            EnsureAlive();
            _ = _mpvCommandString(_ctx, "stop");
        }
        return Task.CompletedTask;
    }


    public Task SeekByAsync(TimeSpan delta, CancellationToken ct = default)
    {
        lock (_gate)
        {
            EnsureAlive();
            var sec = delta.TotalSeconds.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture);
            _ = _mpvCommandString(_ctx, $"seek {sec} relative");
        }
        return Task.CompletedTask;
    }

    public Task ToggleMuteAsync(CancellationToken ct = default)
    {
        lock (_gate)
        {
            EnsureAlive();
            _muted = !_muted;
            SetPropertyString("mute", _muted ? "yes" : "no");
        }
        return Task.CompletedTask;
    }

    public Task SeekAsync(TimeSpan position, CancellationToken ct = default)
    {
        lock (_gate)
        {
            EnsureAlive();
            var sec = position.TotalSeconds.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture);
            _ = _mpvCommandString(_ctx, $"seek {sec} absolute");
        }
        return Task.CompletedTask;
    }

    public Task<TimeSpan> GetPositionAsync(CancellationToken ct = default)
    {
        lock (_gate)
        {
            EnsureAlive();
            if (_mpvGetProperty(_ctx, "time-pos", MpvFormatString, out var ptr) < 0 || ptr == IntPtr.Zero)
            {
                return Task.FromResult(TimeSpan.Zero);
            }

            try
            {
                var s = Marshal.PtrToStringUTF8(ptr) ?? "0";
                if (double.TryParse(s, System.Globalization.NumberStyles.Float,
                        System.Globalization.CultureInfo.InvariantCulture, out var sec))
                {
                    return Task.FromResult(TimeSpan.FromSeconds(sec));
                }
            }
            finally
            {
                _mpvFree(ptr);
            }
        }

        return Task.FromResult(TimeSpan.Zero);
    }

    private void Command(params string[] args)
    {
        // NULL-terminated array of UTF-8 string pointers.
        var ptrs = new IntPtr[args.Length + 1];
        try
        {
            for (var i = 0; i < args.Length; i++)
            {
                ptrs[i] = Utf8(args[i]);
            }

            var array = Marshal.AllocHGlobal(IntPtr.Size * ptrs.Length);
            try
            {
                for (var i = 0; i < ptrs.Length; i++)
                {
                    Marshal.WriteIntPtr(array, i * IntPtr.Size, ptrs[i]);
                }

                var rc = _mpvCommand(_ctx, array);
                if (rc < 0)
                {
                    throw new InvalidOperationException($"mpv_command failed ({rc}) for {args[0]}");
                }
            }
            finally
            {
                Marshal.FreeHGlobal(array);
            }
        }
        finally
        {
            foreach (var p in ptrs)
            {
                if (p != IntPtr.Zero) Marshal.FreeHGlobal(p);
            }
        }
    }

    private static IntPtr Utf8(string s)
    {
        var bytes = Encoding.UTF8.GetBytes(s + "\0");
        var ptr = Marshal.AllocHGlobal(bytes.Length);
        Marshal.Copy(bytes, 0, ptr, bytes.Length);
        return ptr;
    }

    private void SetPropertyString(string name, string value)
    {
        var rc = _mpvSetPropertyString(_ctx, name, value);
        if (rc < 0)
        {
            // Non-fatal for optional props.
        }
    }

    private void EnsureAlive()
    {
        if (_ctx == IntPtr.Zero)
        {
            throw new ObjectDisposedException(nameof(LibMpvMediaPlayer));
        }
    }

    private void EventLoop()
    {
        while (_running && _ctx != IntPtr.Zero)
        {
            IntPtr evPtr;
            try
            {
                evPtr = _mpvWaitEvent(_ctx, 0.5);
            }
            catch
            {
                break;
            }

            if (evPtr == IntPtr.Zero) continue;
            var id = Marshal.ReadInt32(evPtr); // event_id is first field of mpv_event
            if (id == MpvEventEndFile)
            {
                try { PlaybackEnded?.Invoke(); } catch { /* UI may be gone */ }
            }
            else if (id == MpvEventShutdown)
            {
                break;
            }
        }
    }

    public void Dispose()
    {
        _running = false;
        lock (_gate)
        {
            if (_ctx != IntPtr.Zero)
            {
                _mpvTerminateDestroy(_ctx);
                _ctx = IntPtr.Zero;
            }
        }

        try { _eventThread?.Join(1000); } catch { /* ignore */ }
        // Keep library loaded for process lifetime; Freeing while other players
        // might exist is risky. NativeLibrary.Free is intentionally skipped.
        GC.SuppressFinalize(this);
    }

    public string LibraryPath => _libraryPath;
}
