using DramaRed.UI.Services;
using Xunit;

namespace DramaRed.UI.Tests;

public class DaemonClientTests
{
    [Fact]
    public async Task Discover_maps_502_to_chinese_without_httpexception_text()
    {
        await using var fake = new FakeDaemonServer { FailDiscover = true };
        using var client = new DaemonClient(fake.BaseAddress);

        var ex = await Assert.ThrowsAsync<DaemonApiException>(() => client.DiscoverAsync(TestContext.Current.CancellationToken));
        Assert.Contains("推荐失败", ex.Message);
        Assert.DoesNotContain("HttpRequestException", ex.Message);
        Assert.DoesNotContain("Response status code does not indicate success", ex.Message);
        Assert.Contains("重试", ex.Message);
    }

    [Fact]
    public async Task Health_and_discover_succeed_against_fake_daemon()
    {
        await using var fake = new FakeDaemonServer();
        using var client = new DaemonClient(fake.BaseAddress);
        Assert.True(await client.HealthAsync(TestContext.Current.CancellationToken));
        var page = await client.DiscoverAsync(TestContext.Current.CancellationToken);
        Assert.NotNull(page);
        Assert.Equal(2, page!.Items.Count);
        Assert.Equal("测试短剧甲", page.Items[0].Title);
    }

    [Fact]
    public async Task Search_episodes_playback_chain()
    {
        await using var fake = new FakeDaemonServer();
        using var client = new DaemonClient(fake.BaseAddress);
        var search = await client.SearchAsync("x", TestContext.Current.CancellationToken);
        Assert.Single(search!.Items);
        var eps = await client.EpisodesAsync("s1", TestContext.Current.CancellationToken);
        Assert.Equal(3, eps!.Items.Count);
        var pb = await client.PlaybackAsync("e1", TestContext.Current.CancellationToken);
        Assert.NotNull(pb!.Playback);
        Assert.NotEmpty(pb.Playback!.Streams);
        Assert.StartsWith("https://", pb.Playback.Streams[0].Url);
    }

    [Fact]
    public async Task Discover_caller_cancel_does_not_hang()
    {
        await using var fake = new FakeDaemonServer { DiscoverDelayMs = 15_000 };
        using var client = new DaemonClient(fake.BaseAddress);
        using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(250));
        await Assert.ThrowsAnyAsync<OperationCanceledException>(
            () => client.DiscoverAsync(cts.Token));
    }

}
