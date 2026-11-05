using System.Net.Http.Json;
using System.Text.Json;
using DramaRed.UI.Models;

namespace DramaRed.UI.Services;

/// <summary>Avalonia → Go daemon HTTP client.</summary>
public sealed class DaemonClient : IDisposable
{
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    private readonly HttpClient _http;

    public DaemonClient(string baseAddress = "http://127.0.0.1:17890/")
    {
        BaseAddress = baseAddress;
        _http = new HttpClient { BaseAddress = new Uri(baseAddress), Timeout = TimeSpan.FromSeconds(60) };
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

    public Task<PageResult<SeriesSummary>?> SearchAsync(string query, CancellationToken ct = default) =>
        GetAsync<PageResult<SeriesSummary>>($"api/v1/search?q={Uri.EscapeDataString(query)}", ct);

    public Task<PageResult<SeriesSummary>?> DiscoverAsync(CancellationToken ct = default) =>
        GetAsync<PageResult<SeriesSummary>>("api/v1/discover", ct);

    public Task<PageResult<EpisodeItem>?> EpisodesAsync(string seriesId, CancellationToken ct = default) =>
        GetAsync<PageResult<EpisodeItem>>($"api/v1/series/{Uri.EscapeDataString(seriesId)}/episodes", ct);

    public Task<PlaybackResponse?> PlaybackAsync(string episodeId, CancellationToken ct = default) =>
        GetAsync<PlaybackResponse>($"api/v1/episodes/{Uri.EscapeDataString(episodeId)}/playback", ct);

    public Task<HistoryListResponse?> HistoryListAsync(CancellationToken ct = default) =>
        GetAsync<HistoryListResponse>("api/v1/history", ct);

    public async Task HistoryUpsertAsync(HistoryItem item, CancellationToken ct = default)
    {
        using var resp = await _http.PostAsJsonAsync("api/v1/history", item, JsonOpts, ct);
        resp.EnsureSuccessStatusCode();
    }

    public async Task HistoryDeleteAsync(string seriesId, CancellationToken ct = default)
    {
        using var resp = await _http.DeleteAsync(
            $"api/v1/history?seriesId={Uri.EscapeDataString(seriesId)}", ct);
        resp.EnsureSuccessStatusCode();
    }

    public Task<FavoritesListResponse?> FavoritesListAsync(CancellationToken ct = default) =>
        GetAsync<FavoritesListResponse>("api/v1/favorites", ct);

    public async Task FavoritesAddAsync(string seriesId, CancellationToken ct = default)
    {
        using var resp = await _http.PostAsJsonAsync(
            "api/v1/favorites", new { seriesId }, JsonOpts, ct);
        resp.EnsureSuccessStatusCode();
    }

    public async Task FavoritesRemoveAsync(string seriesId, CancellationToken ct = default)
    {
        using var resp = await _http.DeleteAsync(
            $"api/v1/favorites?seriesId={Uri.EscapeDataString(seriesId)}", ct);
        resp.EnsureSuccessStatusCode();
    }

    private async Task<T?> GetAsync<T>(string path, CancellationToken ct)
    {
        using var resp = await _http.GetAsync(path, ct);
        resp.EnsureSuccessStatusCode();
        return await resp.Content.ReadFromJsonAsync<T>(JsonOpts, ct);
    }

    public void Dispose() => _http.Dispose();
}
