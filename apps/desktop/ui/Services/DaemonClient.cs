using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using DramaRed.UI.Models;

namespace DramaRed.UI.Services;

/// <summary>Avalonia → Go daemon HTTP client（中文错误 + 瞬时失败重试）。</summary>
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
        _http = new HttpClient { BaseAddress = new Uri(baseAddress), Timeout = TimeSpan.FromSeconds(90) };
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
        GetAsync<PageResult<SeriesSummary>>($"api/v1/search?q={Uri.EscapeDataString(query)}", "搜索", ct);

    public Task<PageResult<SeriesSummary>?> DiscoverAsync(CancellationToken ct = default) =>
        GetAsync<PageResult<SeriesSummary>>("api/v1/discover", "推荐", ct);

    public Task<PageResult<EpisodeItem>?> EpisodesAsync(string seriesId, CancellationToken ct = default) =>
        GetAsync<PageResult<EpisodeItem>>($"api/v1/series/{Uri.EscapeDataString(seriesId)}/episodes", "分集", ct);

    public Task<PlaybackResponse?> PlaybackAsync(string episodeId, CancellationToken ct = default) =>
        GetAsync<PlaybackResponse>($"api/v1/episodes/{Uri.EscapeDataString(episodeId)}/playback", "播放地址", ct);

    public Task<HistoryListResponse?> HistoryListAsync(CancellationToken ct = default) =>
        GetAsync<HistoryListResponse>("api/v1/history", "历史", ct, retries: 1);

    public async Task HistoryUpsertAsync(HistoryItem item, CancellationToken ct = default)
    {
        using var resp = await _http.PostAsJsonAsync("api/v1/history", item, JsonOpts, ct);
        await EnsureOkAsync(resp, "写入历史", ct);
    }

    public async Task HistoryDeleteAsync(string seriesId, CancellationToken ct = default)
    {
        using var resp = await _http.DeleteAsync(
            $"api/v1/history?seriesId={Uri.EscapeDataString(seriesId)}", ct);
        await EnsureOkAsync(resp, "删除历史", ct);
    }

    public Task<FavoritesListResponse?> FavoritesListAsync(CancellationToken ct = default) =>
        GetAsync<FavoritesListResponse>("api/v1/favorites", "收藏", ct, retries: 1);

    public async Task FavoritesAddAsync(string seriesId, CancellationToken ct = default)
    {
        using var resp = await _http.PostAsJsonAsync(
            "api/v1/favorites", new { seriesId }, JsonOpts, ct);
        await EnsureOkAsync(resp, "添加收藏", ct);
    }

    public async Task FavoritesRemoveAsync(string seriesId, CancellationToken ct = default)
    {
        using var resp = await _http.DeleteAsync(
            $"api/v1/favorites?seriesId={Uri.EscapeDataString(seriesId)}", ct);
        await EnsureOkAsync(resp, "取消收藏", ct);
    }

    private async Task<T?> GetAsync<T>(string path, string op, CancellationToken ct, int retries = 3)
    {
        Exception? last = null;
        for (var attempt = 1; attempt <= retries; attempt++)
        {
            try
            {
                using var resp = await _http.GetAsync(path, ct);
                if (IsTransient(resp.StatusCode) && attempt < retries)
                {
                    await Task.Delay(TimeSpan.FromMilliseconds(300 * attempt * attempt), ct);
                    continue;
                }

                await EnsureOkAsync(resp, op, ct);
                return await resp.Content.ReadFromJsonAsync<T>(JsonOpts, ct);
            }
            catch (OperationCanceledException) { throw; }
            catch (DaemonApiException)
            {
                throw;
            }
            catch (HttpRequestException ex) when (attempt < retries)
            {
                last = ex;
                await Task.Delay(TimeSpan.FromMilliseconds(300 * attempt * attempt), ct);
            }
            catch (HttpRequestException ex)
            {
                throw new DaemonApiException(FriendlyNetwork(op, ex), ex);
            }
        }

        throw new DaemonApiException($"{op}失败：本地服务无响应，请确认 drama-daemon 已启动", last);
    }

    private static bool IsTransient(HttpStatusCode code) =>
        code is HttpStatusCode.BadGateway
            or HttpStatusCode.ServiceUnavailable
            or HttpStatusCode.GatewayTimeout
            or HttpStatusCode.TooManyRequests
            or HttpStatusCode.RequestTimeout;

    private static async Task EnsureOkAsync(HttpResponseMessage resp, string op, CancellationToken ct)
    {
        if (resp.IsSuccessStatusCode) return;

        string? body = null;
        try { body = await resp.Content.ReadAsStringAsync(ct); } catch { /* ignore */ }

        string? message = null;
        if (!string.IsNullOrWhiteSpace(body))
        {
            try
            {
                using var doc = JsonDocument.Parse(body);
                if (doc.RootElement.TryGetProperty("message", out var m))
                    message = m.GetString();
                else if (doc.RootElement.TryGetProperty("error", out var e))
                    message = e.GetString();
            }
            catch { /* ignore */ }
        }

        var zh = message;
        if (string.IsNullOrWhiteSpace(zh))
        {
            zh = resp.StatusCode switch
            {
                HttpStatusCode.BadGateway => "上游短剧服务暂时不可用，请稍后重试",
                HttpStatusCode.ServiceUnavailable => "上游短剧服务繁忙，请稍后重试",
                HttpStatusCode.GatewayTimeout => "上游短剧服务响应超时，请稍后重试",
                HttpStatusCode.TooManyRequests => "请求过于频繁，请稍后再试",
                HttpStatusCode.NotFound => "未找到内容",
                _ => $"请求失败（{(int)resp.StatusCode}）",
            };
        }

        throw new DaemonApiException($"{op}失败：{zh}");
    }

    private static string FriendlyNetwork(string op, Exception ex)
    {
        var msg = ex.Message ?? "";
        if (msg.Contains("Connection refused", StringComparison.OrdinalIgnoreCase) ||
            msg.Contains("actively refused", StringComparison.OrdinalIgnoreCase))
        {
            return $"{op}失败：本地服务未启动，正在尝试拉起或请检查 drama-daemon";
        }

        return $"{op}失败：网络异常，请稍后重试";
    }

    public void Dispose() => _http.Dispose();
}

public sealed class DaemonApiException : Exception
{
    public DaemonApiException(string message, Exception? inner = null) : base(message, inner) { }
}
