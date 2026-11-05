using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Interactivity;
using DramaRed.UI.Services;

namespace DramaRed.UI.Views;

public partial class MainWindow : Window
{
    private readonly DaemonClient _daemon = new();
    private readonly MpvPlayerHost _player = new();

    public MainWindow()
    {
        InitializeComponent();
        PlayerBackend.Text = $"播放后端：{_player.BackendDetail}";
        StatusBar.Text = $"TFM=net10.0 · {_player.BackendDetail}";
    }

    private async void OnSearch(object? sender, RoutedEventArgs e)
    {
        var q = SearchBox.Text ?? "";
        if (string.IsNullOrWhiteSpace(q))
        {
            SearchHint.Text = "请输入关键词";
            return;
        }
        SearchHint.Text = "搜索中…";
        try
        {
            var page = await _daemon.SearchAsync(q);
            if (page is null)
            {
                SearchHint.Text = "空响应";
                return;
            }
            var count = 0;
            if (page.Value.TryGetProperty("items", out var items) && items.ValueKind == JsonValueKind.Array)
            {
                count = items.GetArrayLength();
            }
            SearchHint.Text = $"OK：约 {count} 条";
        }
        catch (Exception ex)
        {
            SearchHint.Text = $"失败：{ex.Message}（先启动 daemon）";
        }
    }

    private void OnExit(object? sender, RoutedEventArgs e) => Close();

    private async void OnAbout(object? sender, RoutedEventArgs e)
    {
        var healthy = await _daemon.HealthAsync();
        StatusBar.Text = healthy
            ? $"daemon OK · {_player.BackendDetail}"
            : $"daemon 未响应 · {_player.BackendDetail}";
    }

    protected override void OnClosed(EventArgs e)
    {
        _player.Dispose();
        _daemon.Dispose();
        base.OnClosed(e);
    }
}
