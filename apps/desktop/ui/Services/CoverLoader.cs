using System.Collections.Concurrent;
using System.Diagnostics;
using Avalonia;
using Avalonia.Media.Imaging;
using Avalonia.Platform;

namespace DramaRed.UI.Services;

/// <summary>Downloads poster images once and caches decoded bitmaps.</summary>
public static class CoverLoader
{
    private static readonly HttpClient Http = new()
    {
        Timeout = TimeSpan.FromSeconds(20),
    };

    private static readonly ConcurrentDictionary<string, Bitmap?> Cache = new();
    private static Bitmap? _placeholder;
    private static string? _cachedFfmpegPath;
    private static bool _ffmpegResolved;

    /// <summary>Solid dark tile used when a cover cannot be decoded (e.g. HEIC without ffmpeg).</summary>
    public static Bitmap Placeholder
    {
        get
        {
            if (_placeholder != null) return _placeholder;
            _placeholder = CreateSolidBitmap(8, 8, 0x2A, 0x26, 0x26); // BGRA matches #26262A
            return _placeholder;
        }
    }

    public static async Task<Bitmap?> LoadAsync(string? url, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(url)) return null;
        if (Cache.TryGetValue(url, out var cached)) return cached;

        try
        {
            using var resp = await Http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, ct);
            resp.EnsureSuccessStatusCode();
            var bytes = await resp.Content.ReadAsByteArrayAsync(ct);
            var contentType = resp.Content.Headers.ContentType?.MediaType ?? "";
            var looksHeic = contentType.Contains("heic", StringComparison.OrdinalIgnoreCase)
                || contentType.Contains("heif", StringComparison.OrdinalIgnoreCase)
                || url.Contains(".heic", StringComparison.OrdinalIgnoreCase);

            Bitmap? bmp = null;
            if (!looksHeic)
            {
                try
                {
                    await using var ms = new MemoryStream(bytes);
                    bmp = new Bitmap(ms);
                }
                catch
                {
                    looksHeic = true; // decode failed — try convert path
                }
            }

            if (bmp == null && looksHeic)
            {
                bmp = await DecodeHeicAsync(bytes, ct);
            }

            // Never leave cards blank when we had a URL — dark placeholder keeps titles readable.
            bmp ??= Placeholder;
            Cache[url] = bmp;
            return bmp;
        }
        catch
        {
            Cache.TryAdd(url, Placeholder);
            return Placeholder;
        }
    }

    private static async Task<Bitmap?> DecodeHeicAsync(byte[] bytes, CancellationToken ct)
    {
        var dir = Path.Combine(Path.GetTempPath(), "dramared-covers");
        Directory.CreateDirectory(dir);
        var id = Guid.NewGuid().ToString("N");
        var src = Path.Combine(dir, id + ".heic");
        var dst = Path.Combine(dir, id + ".png");
        try
        {
            await File.WriteAllBytesAsync(src, bytes, ct);
            var ffmpeg = FindFfmpeg();
            if (ffmpeg == null) return null;
            var psi = new ProcessStartInfo
            {
                FileName = ffmpeg,
                Arguments = $"-y -i \"{src}\" -frames:v 1 \"{dst}\"",
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true,
            };
            using var proc = Process.Start(psi);
            if (proc == null) return null;
            await proc.WaitForExitAsync(ct);
            if (proc.ExitCode != 0 || !File.Exists(dst)) return null;
            await using var fs = File.OpenRead(dst);
            return new Bitmap(fs);
        }
        catch
        {
            return null;
        }
        finally
        {
            try { File.Delete(src); } catch { /* ignore */ }
            try { File.Delete(dst); } catch { /* ignore */ }
        }
    }

    /// <summary>Prefer bundled ffmpeg next to the exe, then PATH.</summary>
    internal static string? FindFfmpeg()
    {
        if (_ffmpegResolved) return _cachedFfmpegPath;
        _ffmpegResolved = true;

        var bundled = Path.Combine(
            AppContext.BaseDirectory,
            OperatingSystem.IsWindows() ? "ffmpeg.exe" : "ffmpeg");
        if (File.Exists(bundled))
        {
            _cachedFfmpegPath = bundled;
            return _cachedFfmpegPath;
        }

        foreach (var name in new[] { "ffmpeg", "ffmpeg.exe" })
        {
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = OperatingSystem.IsWindows() ? "where" : "which",
                    Arguments = name,
                    RedirectStandardOutput = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                };
                using var p = Process.Start(psi);
                if (p == null) continue;
                var path = p.StandardOutput.ReadLine();
                p.WaitForExit(2000);
                if (!string.IsNullOrWhiteSpace(path) && File.Exists(path.Trim()))
                {
                    _cachedFfmpegPath = path.Trim();
                    return _cachedFfmpegPath;
                }
            }
            catch { /* try next */ }
        }

        _cachedFfmpegPath = null;
        return null;
    }

    internal static void ResetForTests()
    {
        Cache.Clear();
        _ffmpegResolved = false;
        _cachedFfmpegPath = null;
    }

    private static WriteableBitmap CreateSolidBitmap(int w, int h, byte b, byte g, byte r)
    {
        var bmp = new WriteableBitmap(
            new PixelSize(w, h),
            new Vector(96, 96),
            PixelFormat.Bgra8888,
            AlphaFormat.Opaque);
        using var fb = bmp.Lock();
        var rowBytes = fb.RowBytes;
        var pixel = new byte[] { b, g, r, 0xFF };
        for (var y = 0; y < h; y++)
        {
            for (var x = 0; x < w; x++)
            {
                var offset = y * rowBytes + x * 4;
                System.Runtime.InteropServices.Marshal.Copy(pixel, 0, fb.Address + offset, 4);
            }
        }
        return bmp;
    }
}
