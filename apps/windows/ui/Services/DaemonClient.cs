using System.Net.Http.Json;
using System.Text.Json;

namespace DramaRed.UI.Services;

/// <summary>
/// Avalonia → Go daemon 的 HTTP 客户端占位。
/// </summary>
public sealed class DaemonClient : IDisposable
{
    private readonly HttpClient _http;

    public DaemonClient(string baseAddress = "http://127.0.0.1:17890/")
    {
        BaseAddress = baseAddress;
        _http = new HttpClient { BaseAddress = new Uri(baseAddress), Timeout = TimeSpan.FromSeconds(30) };
    }

    public string BaseAddress { get; }

    public async Task<bool> HealthAsync(CancellationToken ct = default)
    {
        try
        {
            using var resp = await _http.GetAsync("health", ct);
            return resp.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    public Task<JsonElement?> SearchAsync(string query, CancellationToken ct = default) =>
        GetJsonAsync($"api/v1/search?q={Uri.EscapeDataString(query)}", ct);

    public Task<JsonElement?> DiscoverAsync(CancellationToken ct = default) =>
        GetJsonAsync("api/v1/discover", ct);

    public Task<JsonElement?> EpisodesAsync(string seriesId, CancellationToken ct = default) =>
        GetJsonAsync($"api/v1/series/{Uri.EscapeDataString(seriesId)}/episodes", ct);

    public Task<JsonElement?> PlaybackAsync(string episodeId, CancellationToken ct = default) =>
        GetJsonAsync($"api/v1/episodes/{Uri.EscapeDataString(episodeId)}/playback", ct);

    private async Task<JsonElement?> GetJsonAsync(string path, CancellationToken ct)
    {
        using var resp = await _http.GetAsync(path, ct);
        resp.EnsureSuccessStatusCode();
        return await resp.Content.ReadFromJsonAsync<JsonElement>(cancellationToken: ct);
    }

    public void Dispose() => _http.Dispose();
}
