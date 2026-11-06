using System.Net;
using System.Text;
using System.Text.Json;

namespace DramaRed.UI.Tests;

/// <summary>Minimal local stand-in for drama-daemon HTTP API.</summary>
public sealed class FakeDaemonServer : IAsyncDisposable
{
    private readonly HttpListener _listener = new();
    private readonly CancellationTokenSource _cts = new();
    private Task? _loop;
    private int _discoverCalls;

    public string BaseAddress { get; }
    public int DiscoverCalls => _discoverCalls;
    public bool FailDiscover { get; set; }
    public string FailDiscoverMessage { get; set; } = "上游短剧服务暂时不可用（网关错误），请稍后重试";
    /// <summary>Artificial delay before answering /api/v1/discover (tests timeout UX).</summary>
    public int DiscoverDelayMs { get; set; }
    public bool SearchReturnsEmpty { get; set; }

    public FakeDaemonServer()
    {
        // Port 0 is not supported by HttpListener; pick ephemeral via TcpListener.
        var port = GetFreePort();
        BaseAddress = $"http://127.0.0.1:{port}/";
        _listener.Prefixes.Add(BaseAddress);
        _listener.Start();
        _loop = Task.Run(ListenLoop);
    }

    private static int GetFreePort()
    {
        var l = new System.Net.Sockets.TcpListener(IPAddress.Loopback, 0);
        l.Start();
        var port = ((IPEndPoint)l.LocalEndpoint).Port;
        l.Stop();
        return port;
    }

    private async Task ListenLoop()
    {
        while (!_cts.IsCancellationRequested)
        {
            HttpListenerContext ctx;
            try
            {
                ctx = await _listener.GetContextAsync().WaitAsync(_cts.Token);
            }
            catch (Exception) when (_cts.IsCancellationRequested)
            {
                break;
            }
            catch
            {
                continue;
            }

            _ = Task.Run(() => Handle(ctx));
        }
    }

    private void Handle(HttpListenerContext ctx)
    {
        try
        {
            var path = ctx.Request.Url?.AbsolutePath ?? "";
            if (path == "/health")
            {
                WriteJson(ctx, 200, new { ok = true, service = "fake-daemon", sdk = "test" });
                return;
            }

            if (path == "/api/v1/discover")
            {
                Interlocked.Increment(ref _discoverCalls);
                if (DiscoverDelayMs > 0)
                {
                    Thread.Sleep(DiscoverDelayMs);
                }
                if (FailDiscover)
                {
                    WriteJson(ctx, 502, new { error = "bad gateway", message = FailDiscoverMessage });
                    return;
                }

                WriteJson(ctx, 200, new
                {
                    items = new[]
                    {
                        new
                        {
                            id = "s1",
                            title = "测试短剧甲",
                            description = "desc",
                            cover_url = "",
                            episode_count = 3,
                            author = "A",
                            category = "都市",
                        },
                        new
                        {
                            id = "s2",
                            title = "测试短剧乙",
                            description = "desc2",
                            cover_url = "",
                            episode_count = 5,
                            author = "B",
                            category = "重生",
                        },
                    },
                    has_more = false,
                });
                return;
            }

            if (path == "/api/v1/search")
            {
                if (SearchReturnsEmpty)
                {
                    WriteJson(ctx, 200, new { items = Array.Empty<object>(), has_more = false });
                    return;
                }
                WriteJson(ctx, 200, new
                {
                    items = new[]
                    {
                        new
                        {
                            id = "s3",
                            title = "搜索命中剧",
                            description = "",
                            cover_url = "",
                            episode_count = 2,
                            author = "",
                            category = "",
                        },
                    },
                    has_more = false,
                });
                return;
            }

            if (path == "/api/v1/series/batch")
            {
                WriteJson(ctx, 200, new
                {
                    items = new[]
                    {
                        new
                        {
                            id = "s1",
                            title = "测试短剧甲",
                            description = "desc",
                            cover_url = "https://example.invalid/s1.jpg",
                            episode_count = 3,
                            author = "A",
                            category = "都市",
                        },
                    },
                    has_more = false,
                });
                return;
            }

            if (path.StartsWith("/api/v1/series/", StringComparison.Ordinal) && path.EndsWith("/episodes", StringComparison.Ordinal))
            {
                WriteJson(ctx, 200, new
                {
                    items = new[]
                    {
                        new { id = "e1", series_id = "s1", number = 1, title = "开端", playable = true },
                        new { id = "e2", series_id = "s1", number = 2, title = "转折", playable = true },
                        new { id = "e3", series_id = "s1", number = 3, title = "终章", playable = true },
                    },
                    has_more = false,
                });
                return;
            }

            if (path.StartsWith("/api/v1/episodes/", StringComparison.Ordinal) && path.EndsWith("/playback", StringComparison.Ordinal))
            {
                WriteJson(ctx, 200, new
                {
                    playback = new
                    {
                        episode_id = "e1",
                        @protected = false,
                        streams = new[]
                        {
                            new { definition = "720p", quality = "高清", height = 720, url = "https://example.invalid/a.m3u8", @protected = false },
                        },
                    },
                });
                return;
            }

            if (path == "/api/v1/history")
            {
                if (ctx.Request.HttpMethod == "GET")
                    WriteJson(ctx, 200, new { items = Array.Empty<object>() });
                else
                    WriteJson(ctx, 200, new { status = "ok" });
                return;
            }

            if (path == "/api/v1/favorites")
            {
                if (ctx.Request.HttpMethod == "GET")
                    WriteJson(ctx, 200, new { seriesIds = Array.Empty<string>() });
                else
                    WriteJson(ctx, 200, new { status = "ok" });
                return;
            }

            WriteJson(ctx, 404, new { error = "not found", message = "未找到内容" });
        }
        catch
        {
            try { ctx.Response.Abort(); } catch { /* ignore */ }
        }
    }

    private static void WriteJson(HttpListenerContext ctx, int status, object body)
    {
        var json = JsonSerializer.Serialize(body);
        var bytes = Encoding.UTF8.GetBytes(json);
        ctx.Response.StatusCode = status;
        ctx.Response.ContentType = "application/json; charset=utf-8";
        ctx.Response.ContentLength64 = bytes.Length;
        ctx.Response.OutputStream.Write(bytes);
        ctx.Response.OutputStream.Close();
    }

    public async ValueTask DisposeAsync()
    {
        _cts.Cancel();
        try { _listener.Stop(); } catch { /* ignore */ }
        _listener.Close();
        if (_loop != null)
        {
            try { await _loop.WaitAsync(TimeSpan.FromSeconds(2)); } catch { /* ignore */ }
        }
        _cts.Dispose();
    }
}
