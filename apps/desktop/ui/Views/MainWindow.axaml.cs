using System.Collections.ObjectModel;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Interactivity;
using Avalonia.Threading;
using DramaRed.UI.Models;
using DramaRed.UI.Services;

namespace DramaRed.UI.Views;

public partial class MainWindow : Window
{
    private readonly DaemonClient _daemon = new();
    private readonly MpvPlayerHost _player = new();
    private readonly ObservableCollection<SeriesSummary> _series = new();
    private readonly ObservableCollection<EpisodeItem> _episodes = new();
    private readonly ObservableCollection<HistoryItem> _history = new();
    private readonly ObservableCollection<string> _favorites = new();

    private SeriesSummary? _currentSeries;
    private EpisodeItem? _currentEpisode;
    private List<EpisodeItem> _episodeSnapshot = new();
    private DispatcherTimer? _stopTimer;
    private DispatcherTimer? _progressTimer;
    private DateTimeOffset? _stopDeadline;
    private TrayIcon? _tray;

    public MainWindow()
    {
        InitializeComponent();
        RateBox.SelectedIndex = 1;
        StopAfterBox.SelectedIndex = 0;
        SeriesList.ItemsSource = _series;
        EpisodeList.ItemsSource = _episodes;
        HistoryList.ItemsSource = _history;
        FavoritesList.ItemsSource = _favorites;

        PlayerBackend.Text = $"播放后端：{_player.BackendDetail}";
        StatusBar.Text = $"TFM=net10.0 · {_player.BackendDetail}";
        if (_player.IsNullBackend)
        {
            PlayerStatus.Text = "无 libmpv：控件仍可用；打开流会提示安装系统库。";
        }

        _player.PlaybackEnded += OnPlaybackEnded;
        _progressTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(20) };
        _progressTimer.Tick += async (_, _) => await PersistProgressAsync();
        _progressTimer.Start();

        InitTray();
        Opened += async (_, _) =>
        {
            await RefreshDiscoverAsync();
            await RefreshHistoryAsync();
            await RefreshFavoritesAsync();
            await UpdateHealthAsync();
        };
    }

    private void InitTray()
    {
        try
        {
            _tray = new TrayIcon
            {
                ToolTipText = "DramaRed",
                IsVisible = false,
                Menu = new NativeMenu
                {
                    new NativeMenuItem("显示主窗口") { Command = new SimpleCommand(ShowFromTray) },
                    new NativeMenuItem("暂停") { Command = new SimpleCommand(() => _ = _player.PauseAsync()) },
                    new NativeMenuItem("继续") { Command = new SimpleCommand(() => _ = _player.ResumeAsync()) },
                    new NativeMenuItem("退出") { Command = new SimpleCommand(Close) },
                },
            };
        }
        catch
        {
            _tray = null;
            MenuHideToTray.IsEnabled = false;
        }
    }

    private async Task UpdateHealthAsync()
    {
        var ok = await _daemon.HealthAsync();
        StatusBar.Text = ok
            ? $"daemon OK · {_player.BackendDetail}"
            : $"daemon 未响应（{ _daemon.BaseAddress}）· {_player.BackendDetail}";
    }

    private async void OnRefreshDiscover(object? sender, RoutedEventArgs e) => await RefreshDiscoverAsync();

    private async Task RefreshDiscoverAsync()
    {
        CatalogHint.Text = "加载推荐…";
        try
        {
            var page = await _daemon.DiscoverAsync();
            _series.Clear();
            foreach (var s in page?.Items ?? Enumerable.Empty<SeriesSummary>())
            {
                _series.Add(s);
            }
            CatalogHint.Text = _series.Count == 0 ? "推荐为空" : $"推荐 {_series.Count} 部";
        }
        catch (Exception ex)
        {
            CatalogHint.Text = $"推荐失败：{ex.Message}";
        }
    }

    private async void OnSearch(object? sender, RoutedEventArgs e)
    {
        var q = SearchBox.Text?.Trim() ?? "";
        if (string.IsNullOrEmpty(q))
        {
            CatalogHint.Text = "请输入关键词";
            return;
        }

        CatalogHint.Text = "搜索中…";
        try
        {
            var page = await _daemon.SearchAsync(q);
            _series.Clear();
            foreach (var s in page?.Items ?? Enumerable.Empty<SeriesSummary>())
            {
                _series.Add(s);
            }
            CatalogHint.Text = _series.Count == 0 ? "无结果" : $"搜索到 {_series.Count} 部";
        }
        catch (Exception ex)
        {
            CatalogHint.Text = $"搜索失败：{ex.Message}（先启动 daemon）";
        }
    }

    private async void OnSeriesSelected(object? sender, SelectionChangedEventArgs e)
    {
        if (SeriesList.SelectedItem is SeriesSummary s)
        {
            await LoadEpisodesAsync(s);
        }
    }

    private async void OnSeriesActivate(object? sender, Avalonia.Input.TappedEventArgs e)
    {
        if (SeriesList.SelectedItem is SeriesSummary s)
        {
            await LoadEpisodesAsync(s);
        }
    }

    private async Task LoadEpisodesAsync(SeriesSummary series)
    {
        _currentSeries = series;
        SeriesTitle.Text = series.ListLabel;
        EpisodeHint.Text = "加载分集…";
        try
        {
            var page = await _daemon.EpisodesAsync(series.Id);
            _episodes.Clear();
            _episodeSnapshot = page?.Items?.ToList() ?? new List<EpisodeItem>();
            foreach (var ep in _episodeSnapshot)
            {
                _episodes.Add(ep);
            }
            EpisodeHint.Text = _episodes.Count == 0 ? "暂无分集" : $"{_episodes.Count} 集";
        }
        catch (Exception ex)
        {
            EpisodeHint.Text = $"分集失败：{ex.Message}";
        }
    }

    private async void OnReloadEpisodes(object? sender, RoutedEventArgs e)
    {
        if (_currentSeries != null) await LoadEpisodesAsync(_currentSeries);
    }

    private async void OnEpisodeActivate(object? sender, Avalonia.Input.TappedEventArgs e)
    {
        if (EpisodeList.SelectedItem is EpisodeItem ep)
        {
            await PlayEpisodeAsync(ep, seekMs: 0);
        }
    }

    private async Task PlayEpisodeAsync(EpisodeItem ep, long seekMs)
    {
        _currentEpisode = ep;
        PlayerTitle.Text = _currentSeries == null
            ? ep.ListLabel
            : $"{_currentSeries.Title} · {ep.ListLabel}";
        PlayerStatus.Text = "解析播放地址…";
        try
        {
            var resp = await _daemon.PlaybackAsync(ep.Id);
            var streams = resp?.Playback?.Streams?
                .Where(s => !string.IsNullOrWhiteSpace(s.Url))
                .OrderByDescending(s => s.Height)
                .ToList() ?? new List<PlaybackStream>();
            if (streams.Count == 0)
            {
                PlayerStatus.Text = "无可用流 URL";
                return;
            }

            var best = streams[0];
            var key = resp?.ContentKey?.Key;
            PlayerStatus.Text =
                $"打开 {LabelOf(best)}…{(resp?.DrmProtected == true ? "（DRM/受保护，best-effort key）" : "")}";

            await _player.OpenAsync(best.Url, string.IsNullOrWhiteSpace(key) ? null : key);
            if (seekMs > 0)
            {
                await _player.SeekAsync(TimeSpan.FromMilliseconds(seekMs));
            }

            PlayerStatus.Text =
                $"播放中 · {LabelOf(best)} · 画面在独立 mpv 窗口（DISPLAY 可用时）";
            await _daemon.HistoryUpsertAsync(new HistoryItem
            {
                SeriesId = _currentSeries?.Id ?? ep.SeriesId,
                EpisodeId = ep.Id,
                PositionMs = seekMs,
                UpdatedAt = DateTimeOffset.UtcNow,
            });
            await RefreshHistoryAsync();
        }
        catch (Exception ex)
        {
            PlayerStatus.Text = $"播放失败：{ex.Message}";
        }
    }

    private static string LabelOf(PlaybackStream s) =>
        !string.IsNullOrWhiteSpace(s.Definition) ? s.Definition :
        !string.IsNullOrWhiteSpace(s.Quality) ? s.Quality :
        s.Height > 0 ? $"{s.Height}p" : "stream";

    private async void OnPlaybackEnded()
    {
        await Dispatcher.UIThread.InvokeAsync(async () =>
        {
            if (AutoNextBox.IsChecked != true || _currentEpisode == null) return;
            var idx = _episodeSnapshot.FindIndex(e => e.Id == _currentEpisode.Id);
            if (idx < 0 || idx + 1 >= _episodeSnapshot.Count) return;
            var next = _episodeSnapshot[idx + 1];
            EpisodeList.SelectedItem = next;
            PlayerStatus.Text = $"自动连播：{next.ListLabel}";
            await PlayEpisodeAsync(next, 0);
        });
    }

    private async Task PersistProgressAsync()
    {
        if (_currentEpisode == null) return;
        try
        {
            var pos = await _player.GetPositionAsync();
            await _daemon.HistoryUpsertAsync(new HistoryItem
            {
                SeriesId = _currentSeries?.Id ?? _currentEpisode.SeriesId,
                EpisodeId = _currentEpisode.Id,
                PositionMs = (long)pos.TotalMilliseconds,
                UpdatedAt = DateTimeOffset.UtcNow,
            });
        }
        catch
        {
            // ignore background persist errors
        }
    }

    private async void OnPause(object? sender, RoutedEventArgs e)
    {
        await _player.PauseAsync();
        PlayerStatus.Text = "已暂停";
    }

    private async void OnResume(object? sender, RoutedEventArgs e)
    {
        await _player.ResumeAsync();
        PlayerStatus.Text = "继续播放";
    }

    private async void OnStop(object? sender, RoutedEventArgs e)
    {
        await PersistProgressAsync();
        await _player.StopAsync();
        PlayerStatus.Text = "已停止";
    }

    private void OnRateChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (RateBox?.SelectedItem is not ComboBoxItem item) return;
        var tag = item.Tag?.ToString();
        if (tag != null &&
            double.TryParse(tag, System.Globalization.NumberStyles.Float,
                System.Globalization.CultureInfo.InvariantCulture, out var rate))
        {
            _player.Rate = rate;
        }
    }

    private void OnStopAfterChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (StopAfterBox is null) return;
        _stopTimer?.Stop();
        if (StopAfterBox.SelectedItem is not ComboBoxItem item ||
            !int.TryParse(item.Tag?.ToString(), out var minutes) || minutes <= 0)
        {
            _stopDeadline = null;
            _player.StopAfter = null;
            TimerHint.Text = "定时停止：关";
            return;
        }

        _player.StopAfter = TimeSpan.FromMinutes(minutes);
        _stopDeadline = DateTimeOffset.Now.AddMinutes(minutes);
        TimerHint.Text = $"定时停止：{minutes} 分钟后暂停";
        _stopTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _stopTimer.Tick += async (_, _) =>
        {
            if (_stopDeadline is null) return;
            var left = _stopDeadline.Value - DateTimeOffset.Now;
            if (left <= TimeSpan.Zero)
            {
                _stopTimer.Stop();
                await _player.PauseAsync();
                TimerHint.Text = "定时停止已触发";
                PlayerStatus.Text = "定时停止已触发";
                StopAfterBox.SelectedIndex = 0;
            }
            else
            {
                TimerHint.Text =
                    $"定时停止倒计时 {left.Minutes:00}:{left.Seconds % 60:00}";
            }
        };
        _stopTimer.Start();
    }

    private async void OnFavoriteAdd(object? sender, RoutedEventArgs e)
    {
        if (_currentSeries == null) return;
        try
        {
            await _daemon.FavoritesAddAsync(_currentSeries.Id);
            await RefreshFavoritesAsync();
            StatusBar.Text = $"已收藏 {_currentSeries.Title}";
        }
        catch (Exception ex)
        {
            StatusBar.Text = $"收藏失败：{ex.Message}";
        }
    }

    private async void OnFavoriteRemove(object? sender, RoutedEventArgs e)
    {
        if (_currentSeries == null) return;
        try
        {
            await _daemon.FavoritesRemoveAsync(_currentSeries.Id);
            await RefreshFavoritesAsync();
            StatusBar.Text = $"已取消收藏 {_currentSeries.Title}";
        }
        catch (Exception ex)
        {
            StatusBar.Text = $"取消收藏失败：{ex.Message}";
        }
    }

    private async void OnRefreshHistory(object? sender, RoutedEventArgs e) => await RefreshHistoryAsync();
    private async void OnRefreshFavorites(object? sender, RoutedEventArgs e) => await RefreshFavoritesAsync();

    private async Task RefreshHistoryAsync()
    {
        try
        {
            var page = await _daemon.HistoryListAsync();
            _history.Clear();
            foreach (var h in page?.Items ?? Enumerable.Empty<HistoryItem>())
            {
                _history.Add(h);
            }
        }
        catch
        {
            // daemon may be down
        }
    }

    private async Task RefreshFavoritesAsync()
    {
        try
        {
            var page = await _daemon.FavoritesListAsync();
            _favorites.Clear();
            foreach (var id in page?.SeriesIds ?? Enumerable.Empty<string>())
            {
                _favorites.Add(id);
            }
        }
        catch
        {
            // daemon may be down
        }
    }

    private async void OnHistoryActivate(object? sender, Avalonia.Input.TappedEventArgs e)
    {
        if (HistoryList.SelectedItem is not HistoryItem h) return;
        try
        {
            // Load series episodes then resume.
            var series = _series.FirstOrDefault(s => s.Id == h.SeriesId)
                         ?? new SeriesSummary { Id = h.SeriesId, Title = h.SeriesId };
            await LoadEpisodesAsync(series);
            var ep = _episodeSnapshot.FirstOrDefault(x => x.Id == h.EpisodeId)
                     ?? new EpisodeItem { Id = h.EpisodeId, SeriesId = h.SeriesId, Title = h.EpisodeId };
            await PlayEpisodeAsync(ep, h.PositionMs);
        }
        catch (Exception ex)
        {
            PlayerStatus.Text = $"续播失败：{ex.Message}";
        }
    }

    private async void OnFavoriteActivate(object? sender, Avalonia.Input.TappedEventArgs e)
    {
        if (FavoritesList.SelectedItem is not string id) return;
        var series = _series.FirstOrDefault(s => s.Id == id)
                     ?? new SeriesSummary { Id = id, Title = id };
        SeriesList.SelectedItem = _series.FirstOrDefault(s => s.Id == id);
        await LoadEpisodesAsync(series);
    }

    private void OnHideToTray(object? sender, RoutedEventArgs e)
    {
        if (_tray == null)
        {
            StatusBar.Text = "当前环境无托盘支持；改为仅隐藏窗口（音频继续）";
            Hide();
            return;
        }

        _tray.IsVisible = true;
        Hide();
        StatusBar.Text = "已隐藏到托盘（音频继续）";
    }

    private void OnShowFromTray(object? sender, RoutedEventArgs e) => ShowFromTray();

    private void ShowFromTray()
    {
        Show();
        Activate();
        if (_tray != null) _tray.IsVisible = false;
    }

    private void OnExit(object? sender, RoutedEventArgs e) => Close();

    private async void OnAbout(object? sender, RoutedEventArgs e) => await UpdateHealthAsync();

    protected override async void OnClosed(EventArgs e)
    {
        _stopTimer?.Stop();
        _progressTimer?.Stop();
        try { await PersistProgressAsync(); } catch { /* ignore */ }
        _player.PlaybackEnded -= OnPlaybackEnded;
        _player.Dispose();
        _daemon.Dispose();
        _tray?.Dispose();
        base.OnClosed(e);
    }
}

/// <summary>Tiny ICommand helper for tray menu items.</summary>
file sealed class SimpleCommand : System.Windows.Input.ICommand
{
    private readonly Action _action;
    public SimpleCommand(Action action) => _action = action;
    public bool CanExecute(object? parameter) => true;
    public void Execute(object? parameter) => _action();
#pragma warning disable CS0067
    public event EventHandler? CanExecuteChanged;
#pragma warning restore CS0067
}
