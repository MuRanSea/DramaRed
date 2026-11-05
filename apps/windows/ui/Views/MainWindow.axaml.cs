using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Interactivity;
using DramaRed.UI.Services;

namespace DramaRed.UI.Views;

public partial class MainWindow : Window
{
    private readonly DaemonClient _daemon = new();

    public MainWindow()
    {
        InitializeComponent();
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
            SearchHint.Text = $"OK：约 {count} 条（原始 JSON 长度 {page.Value.GetRawText().Length}）";
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
        SearchHint.Text = healthy ? "daemon 健康" : "daemon 未响应（先启动 Go 进程）";
    }
}
