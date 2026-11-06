using Avalonia.Controls;
using Avalonia.Headless;
using Avalonia.Headless.XUnit;
using Avalonia.Threading;
using Avalonia.VisualTree;
using DramaRed.UI.Models;
using DramaRed.UI.Services;
using DramaRed.UI.Services.Playback;
using DramaRed.UI.Views;
using Xunit;

namespace DramaRed.UI.Tests;

/// <summary>
/// Captures one PNG per desktop feature page for human self-review.
/// Output: docs/smoke-artifacts/feature-review-YYYYMMDD/desktop/
/// </summary>
public class FeatureScreenshotTests
{
    private static readonly string OutDir = ResolveOutDir();

    private static string ResolveOutDir()
    {
        var env = Environment.GetEnvironmentVariable("FEATURE_REVIEW_OUT");
        if (!string.IsNullOrWhiteSpace(env)) return env;
        // ui.Tests/bin/.../net10.0 -> repo root
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "README.md")))
            dir = dir.Parent;
        var stamp = Environment.GetEnvironmentVariable("FEATURE_REVIEW_STAMP") ?? DateTime.Now.ToString("yyyyMMdd");
        return Path.Combine(dir!.FullName, "docs", "smoke-artifacts", $"feature-review-{stamp}", "desktop");
    }

    private static MpvPlayerHost TestPlayer() =>
        new(new NullMediaPlayer(), "播放后端：测试空后端（未加载 libmpv）", isNullBackend: true);

    private static MainWindow CreateWindow(DaemonClient daemon) =>
        new(daemon, player: TestPlayer(), autoBootstrap: false);

    private static async Task Pump(int ms = 80)
    {
        await Dispatcher.UIThread.InvokeAsync(() => { });
        await Task.Delay(ms);
        await Dispatcher.UIThread.InvokeAsync(() => { });
    }

    private static void ClickNav(MainWindow window, string tag)
    {
        var item = window.NavList.Items.OfType<ListBoxItem>()
            .First(i => i.Tag?.ToString() == tag);
        window.NavList.SelectedItem = item;
    }

    private static void Save(MainWindow window, string name)
    {
        Directory.CreateDirectory(OutDir);
        // Headless CaptureRenderedFrame can return null before first paint; force a bitmap render.
        window.UpdateLayout();
        var w = Math.Max(1, (int)window.Bounds.Width);
        var h = Math.Max(1, (int)window.Bounds.Height);
        if (w < 100 || h < 100)
        {
            w = (int)window.Width;
            h = (int)window.Height;
        }
        var bmp = new Avalonia.Media.Imaging.RenderTargetBitmap(
            new Avalonia.PixelSize(w, h),
            new Avalonia.Vector(96, 96));
        bmp.Render(window);
        var path = Path.Combine(OutDir, name + ".png");
        bmp.Save(path);
        Assert.True(File.Exists(path) && new FileInfo(path).Length > 500, path);
        Console.WriteLine($"SHOT {path} bytes={new FileInfo(path).Length}");
    }

    [AvaloniaFact]
    public async Task Capture_all_feature_pages()
    {
        await using var fake = new FakeDaemonServer();
        using var daemon = new DaemonClient(fake.BaseAddress);
        var window = CreateWindow(daemon);
        window.Width = 1360;
        window.Height = 860;
        window.Show();
        await Pump(120);

        await window.TestRefreshDiscoverAsync();
        await Pump(120);
        Save(window, "01-home-recommend");

        ClickNav(window, "theater");
        await Pump();
        Save(window, "02-theater");

        window.TestSetSearchText("总裁");
        await window.TestRunSearchAsync();
        await Pump(120);
        Save(window, "03-search-results");

        await window.TestOpenSeriesAsync(new SeriesSummary
        {
            Id = "s1",
            Title = "测试短剧甲",
            EpisodeCount = 3,
        });
        await Pump(150);
        Save(window, "04-player");

        // next episode via UI helper if available — stay on player, capture chips
        ClickNav(window, "history");
        await Pump();
        Save(window, "05-history");

        ClickNav(window, "favorites");
        await Pump();
        Save(window, "06-favorites");

        ClickNav(window, "settings");
        await Pump();
        Save(window, "07-settings");

        // empty/error home
        fake.FailDiscover = true;
        ClickNav(window, "home");
        await Pump();
        await window.TestRefreshDiscoverAsync();
        await Pump(120);
        Save(window, "08-home-error-retry");

        // icon asset presence (copied separately) — capture window chrome with tomato
        fake.FailDiscover = false;
        await window.TestRefreshDiscoverAsync();
        await Pump(120);
        ClickNav(window, "home");
        await Pump();
        Save(window, "09-shell-with-tomato-icon");

        window.Close();
        Assert.True(Directory.GetFiles(OutDir, "*.png").Length >= 8);
    }
}
