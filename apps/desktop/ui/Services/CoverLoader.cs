using System.Collections.Concurrent;
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
            await using var stream = await resp.Content.ReadAsStreamAsync(ct);
            using var ms = new MemoryStream();
            await stream.CopyToAsync(ms, ct);
            ms.Position = 0;
            var bmp = new Bitmap(ms);
            Cache[url] = bmp;
            return bmp;
        }
        catch
        {
            Cache.TryAdd(url, null);
            return null;
        }
    }
}
