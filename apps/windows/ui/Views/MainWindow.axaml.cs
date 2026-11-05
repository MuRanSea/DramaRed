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
        SearchHint.Text = string.IsNullOrWhiteSpace(q)
            ? "请输入关键词"
            : $"TODO: 搜索 «{q}» → {_daemon.BaseAddress}api/v1/search";
        // var results = await _daemon.SearchAsync(q);
    }

    private void OnExit(object? sender, RoutedEventArgs e) => Close();

    private async void OnAbout(object? sender, RoutedEventArgs e)
    {
        var healthy = await _daemon.HealthAsync();
        SearchHint.Text = healthy ? "daemon 健康" : "daemon 未响应（先启动 Go 进程）";
    }
}
