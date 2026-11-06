using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.Threading;
using Avalonia.VisualTree;
using DramaRed.UI.Models;
using DramaRed.UI.Services;
using DramaRed.UI.Services.Playback;
using DramaRed.UI.Views;
using Xunit;

namespace DramaRed.UI.Tests;

public class MainWindowUiTests
{
    private static MpvPlayerHost TestPlayer() =>
        new(new NullMediaPlayer(), "播放后端：测试空后端（未加载 libmpv）", isNullBackend: true);

    private static MainWindow CreateWindow(DaemonClient daemon) =>
        new(daemon, player: TestPlayer(), autoBootstrap: false);

    [AvaloniaFact]
    public async Task Sidebar_navigation_switches_pages()
    {
        await using var fake = new FakeDaemonServer();
        using var daemon = new DaemonClient(fake.BaseAddress);
        var window = CreateWindow(daemon);
        window.Show();
        await Pump();

        Assert.True(window.PageHome.IsVisible);
        Assert.Equal("home", window.CurrentPage);

        ClickNav(window, "theater");
        await Pump();
        Assert.True(window.PageTheater.IsVisible);
        Assert.False(window.PageHome.IsVisible);
        Assert.Equal("theater", window.CurrentPage);

        ClickNav(window, "search");
        await Pump();
        Assert.True(window.PageSearch.IsVisible);

        ClickNav(window, "player");
        await Pump();
        Assert.True(window.PagePlayer.IsVisible);

        ClickNav(window, "history");
        await Pump();
        Assert.True(window.PageHistory.IsVisible);

        ClickNav(window, "favorites");
        await Pump();
        Assert.True(window.PageFavorites.IsVisible);

        ClickNav(window, "settings");
        await Pump();
        Assert.True(window.PageSettings.IsVisible);
        Assert.Contains("本地服务", GetText(window.PageSettings));

        window.Close();
    }

    [AvaloniaFact]
    public async Task Home_loads_poster_grid_from_daemon()
    {
        await using var fake = new FakeDaemonServer();
        using var daemon = new DaemonClient(fake.BaseAddress);
        var window = CreateWindow(daemon);
        window.Show();
        await Pump();

        await window.TestRefreshDiscoverAsync();
        await Pump();

        Assert.Equal(2, window.HomeCount);
        Assert.Equal(2, window.TheaterCount);
        Assert.False(window.HomeEmpty.IsVisible);
        Assert.Contains("共 2 部", window.HomeHint.Text);

        window.Close();
    }

    [AvaloniaFact]
    public async Task Home_empty_state_shows_chinese_retry_on_502()
    {
        await using var fake = new FakeDaemonServer { FailDiscover = true };
        using var daemon = new DaemonClient(fake.BaseAddress);
        var window = CreateWindow(daemon);
        window.Show();
        await Pump();

        await window.TestRefreshDiscoverAsync();
        await Pump();

        Assert.Equal(0, window.HomeCount);
        Assert.True(window.HomeEmpty.IsVisible);
        Assert.DoesNotContain("HttpRequestException", window.HomeHint.Text ?? "");
        Assert.DoesNotContain("Response status code", window.HomeHint.Text ?? "");
        Assert.Contains("重试", window.HomeEmptyDetail.Text + window.HomeHint.Text);
        // Retry button exists
        var retry = window.GetVisualDescendants().OfType<Button>()
            .FirstOrDefault(b => b.Content?.ToString() == "立即重试");
        Assert.NotNull(retry);

        // Recover
        fake.FailDiscover = false;
        await window.TestRefreshDiscoverAsync();
        await Pump();
        Assert.True(window.HomeCount >= 2);
        Assert.False(window.HomeEmpty.IsVisible);

        window.Close();
    }

    [AvaloniaFact]
    public async Task Search_fills_grid_with_chinese_hint()
    {
        await using var fake = new FakeDaemonServer();
        using var daemon = new DaemonClient(fake.BaseAddress);
        var window = CreateWindow(daemon);
        window.Show();
        await Pump();

        window.TestSetSearchText("总裁");
        await window.TestRunSearchAsync();
        await Pump();

        Assert.Equal("search", window.CurrentPage);
        Assert.Equal(1, window.SearchCount);
        Assert.Contains("搜索到", window.SearchHint.Text);

        window.Close();
    }

    [AvaloniaFact]
    public async Task Player_page_has_chinese_controls_and_episode_chips()
    {
        await using var fake = new FakeDaemonServer();
        using var daemon = new DaemonClient(fake.BaseAddress);
        var window = CreateWindow(daemon);
        window.Show();
        await Pump();

        await window.TestOpenSeriesAsync(new SeriesSummary
        {
            Id = "s1",
            Title = "测试短剧甲",
            EpisodeCount = 3,
        });
        await Pump();

        Assert.Equal("player", window.CurrentPage);
        Assert.True(window.PagePlayer.IsVisible);
        Assert.Equal("测试短剧甲", window.SeriesTitle.Text);
        Assert.Equal(3, window.EpisodeCount);
        Assert.False(window.PlayerEmpty.IsVisible);

        var labels = window.GetVisualDescendants().OfType<Button>()
            .Select(b => b.Content?.ToString() ?? "")
            .ToList();
        foreach (var need in new[] { "上一集", "播放/暂停", "下一集", "停止", "静音", "收藏" })
        {
            Assert.Contains(need, labels);
        }

        Assert.Contains(labels, l => l.StartsWith("第 ") && l.EndsWith(" 集"));
        Assert.DoesNotContain(labels, l => l.Contains("Not Playing", StringComparison.OrdinalIgnoreCase));
        Assert.DoesNotContain(window.PlayerStatus.Text ?? "", "no libmpv candidate", StringComparison.OrdinalIgnoreCase);

        window.Close();
    }

    [AvaloniaFact]
    public async Task Settings_page_shows_daemon_and_backend_blocks()
    {
        await using var fake = new FakeDaemonServer();
        using var daemon = new DaemonClient(fake.BaseAddress);
        var window = CreateWindow(daemon);
        window.Show();
        await Pump();

        window.TestShowPage("settings");
        await Pump();

        var text = GetText(window.PageSettings);
        Assert.Contains("本地服务", text);
        Assert.Contains("播放说明", text);
        Assert.Contains("快捷键", text);
        Assert.Contains("重新检测", text);

        window.Close();
    }

    private static void ClickNav(MainWindow window, string tag)
    {
        var item = window.NavList.Items.OfType<ListBoxItem>()
            .First(i => i.Tag?.ToString() == tag);
        window.NavList.SelectedItem = item;
    }

    private static string GetText(Control root) =>
        string.Join("\n", root.GetVisualDescendants().OfType<TextBlock>().Select(t => t.Text));

    private static async Task Pump()
    {
        // Let layout + async continuations settle.
        await Dispatcher.UIThread.InvokeAsync(() => { });
        await Task.Delay(50);
        await Dispatcher.UIThread.InvokeAsync(() => { });
    }
}
