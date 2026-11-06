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

    private readonly TimeSpan _catalogBudget;

    public DaemonClient(string baseAddress = "http://127.0.0.1:17890/", TimeSpan? timeout = null)
    {
        BaseAddress = baseAddress;
        var httpTimeout = timeout ?? TimeSpan.FromSeconds(28);
        // Catalog budget stays under HttpClient.Timeout so we map cancel ourselves with Chinese copy.
        _catalogBudget = httpTimeout <= TimeSpan.FromSeconds(3)
            ? TimeSpan.FromMilliseconds(Math.Max(200, httpTimeout.TotalMilliseconds - 100))
            : TimeSpan.FromSeconds(Math.Min(25, Math.Max(1, httpTimeout.TotalSeconds - 3)));
        _http = new HttpClient { BaseAddress = new Uri(baseAddress), Timeout = httpTimeout };
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
        GetCatalogAsync<PageResult<SeriesSummary>>($"api/v1/search?q={Uri.EscapeDataString(query)}", "搜索", ct);

    public Task<PageResult<SeriesSummary>?> DiscoverAsync(CancellationToken ct = default) =>
        GetCatalogAsync<PageResult<SeriesSummary>>("api/v1/discover", "推荐", ct);

    /// <summary>Catalog calls use a shorter linked timeout + fewer retries so the UI cannot sit on 「正在加载」 for minutes.</summary>
    private async Task<T?> GetCatalogAsync<T>(string path, string op, CancellationToken ct)
    {
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(ct);
        linked.CancelAfter(_catalogBudget);
        try
        {
            return await GetAsync<T>(path, op, linked.Token, retries: 2);
        }
        catch (Exception ex) when (IsTimeout(ex) && !ct.IsCancellationRequested)
        {
            throw TimeoutException(op, ex);
        }
    }

    private static bool IsTimeout(Exception ex)
    {
        for (Exception? e = ex; e != null; e = e.InnerException)
        {
            if (e is TimeoutException) return true;
            // HttpClient.Timeout surfaces as TaskCanceledException with this English message.
            var msg = e.Message ?? "";
            if (msg.Contains("HttpClient.Timeout", StringComparison.OrdinalIgnoreCase)) return true;
            if (msg.Contains("Timeout of", StringComparison.OrdinalIgnoreCase) &&
                msg.Contains("elapsing", StringComparison.OrdinalIgnoreCase)) return true;
            if (e is TaskCanceledException or OperationCanceledException)
            {
                // Treat cancel-with-timeout-looking-message as timeout; plain cancel checked by caller.
                if (msg.Contains("timeout", StringComparison.OrdinalIgnoreCase) ||
                    msg.Contains("canceled", StringComparison.OrdinalIgnoreCase) ||
                    msg.Contains("cancelled", StringComparison.OrdinalIgnoreCase))
                    return true;
            }
        }
        return false;
    }

    private static DaemonApiException TimeoutException(string op, Exception? inner = null) =>
        new($"{op}失败：推荐加载超时，请重试或用顶栏搜索", inner);

    public Task<PageResult<EpisodeItem>?> EpisodesAsync(string seriesId, CancellationToken ct = default) =>
        GetAsync<PageResult<EpisodeItem>>($"api/v1/series/{Uri.EscapeDataString(seriesId)}/episodes", "分集", ct);

    /// <summary>Batch-enrich series titles/covers (favorites/history placeholders).</summary>
    public Task<PageResult<SeriesSummary>?> SeriesBatchAsync(IEnumerable<string> ids, CancellationToken ct = default)
    {
        var list = ids.Where(id => !string.IsNullOrWhiteSpace(id)).Distinct().Take(20).ToList();
        if (list.Count == 0)
        {
            return Task.FromResult<PageResult<SeriesSummary>?>(new PageResult<SeriesSummary>());
        }
        var q = string.Join(",", list.Select(Uri.EscapeDataString));
        return GetAsync<PageResult<SeriesSummary>>($"api/v1/series/batch?ids={q}", "剧目详情", ct, retries: 1);
    }

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
            catch (Exception ex) when (IsTimeout(ex) && !ct.IsCancellationRequested)
            {
                throw TimeoutException(op, ex);
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
