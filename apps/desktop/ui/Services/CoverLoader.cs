using System.Collections.Concurrent;
using System.Diagnostics;
using Avalonia.Media.Imaging;

namespace DramaRed.UI.Services;

/// <summary>Downloads poster images once and caches decoded bitmaps.</summary>
public static class CoverLoader
{
    private static readonly HttpClient Http = new()
    {
        Timeout = TimeSpan.FromSeconds(20),
    };

    private static readonly ConcurrentDictionary<string, Bitmap?> Cache = new();

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

            Cache[url] = bmp;
            return bmp;
        }
        catch
        {
            Cache.TryAdd(url, null);
            return null;
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

    private static string? FindFfmpeg()
    {
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
                if (!string.IsNullOrWhiteSpace(path) && File.Exists(path.Trim())) return path.Trim();
            }
            catch { /* try next */ }
        }
        var bundled = Path.Combine(AppContext.BaseDirectory, OperatingSystem.IsWindows() ? "ffmpeg.exe" : "ffmpeg");
        return File.Exists(bundled) ? bundled : null;
    }
}
