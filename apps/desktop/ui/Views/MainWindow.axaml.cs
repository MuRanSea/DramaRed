using System.Collections.ObjectModel;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media.Imaging;
using Avalonia.Threading;
using DramaRed.UI.Models;
using DramaRed.UI.Services;

namespace DramaRed.UI.Views;

public partial class MainWindow : Window
{
    private readonly DaemonClient _daemon = new();
    private readonly DaemonSupervisor _supervisor = new();
    private readonly MpvPlayerHost _player = new();
    private readonly Dictionary<string, SeriesSummary> _seriesCache = new();
    private readonly Dictionary<string, PlaybackResponse> _playbackCache = new();
    private readonly ObservableCollection<PosterItem> _home = new();
    private readonly ObservableCollection<PosterItem> _theater = new();
    private readonly ObservableCollection<PosterItem> _search = new();
    private readonly ObservableCollection<PosterItem> _favorites = new();
    private readonly ObservableCollection<HistoryRow> _history = new();
    private readonly ObservableCollection<EpisodeItem> _episodes = new();

    private SeriesSummary? _currentSeries;
    private EpisodeItem? _currentEpisode;
    private List<EpisodeItem> _episodeSnapshot = new();
    private List<PlaybackStream> _streams = new();
    private string _preferredQuality = "自动";
    private bool _favorited;
    private string _lastBrowsePage = "home";
    private string _currentPage = "home";
    private bool _qualityApplying;
    private DispatcherTimer? _stopTimer;
    private DispatcherTimer? _progressTimer;
    private DateTimeOffset? _stopDeadline;
    private TrayIcon? _tray;

    public MainWindow()
    {
        InitializeComponent();
        RateBox.SelectedIndex = 1;
        StopAfterBox.SelectedIndex = 0;
        HomeGrid.ItemsSource = _home;
        TheaterGrid.ItemsSource = _theater;
        SearchGrid.ItemsSource = _search;
        FavoritesGrid.ItemsSource = _favorites;
        HistoryList.ItemsSource = _history;
        EpisodeList.ItemsSource = _episodes;

        PlayerBackend.Text = $"播放后端：{_player.BackendDetail}";
        SettingsBackend.Text = $"播放后端：{_player.BackendDetail}";
        StatusBar.Text = $"TFM=net10.0 · {_player.BackendDetail}";
        if (_player.IsNullBackend)
        {
            PlayerStatus.Text = "无 libmpv：仍可浏览与选剧；打开流会提示安装系统库或将 libmpv-2.dll 放到程序旁。";
        }

        _player.PlaybackEnded += OnPlaybackEnded;
        _progressTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(20) };
        _progressTimer.Tick += async (_, _) => await PersistProgressAsync();
        _progressTimer.Start();

        InitTray();
        Opened += async (_, _) =>
        {
            await EnsureDaemonAsync();
            await RefreshDiscoverAsync();
            await RefreshHistoryAsync();
            await RefreshFavoritesAsync();
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
        }
    }

    private async Task EnsureDaemonAsync()
    {
        try
        {
            var ok = await _supervisor.EnsureRunningAsync(_daemon);
            var detail = ok
                ? (_supervisor.StartedByUs
                    ? $"daemon OK（已自动拉起 {_supervisor.DaemonPath}）"
                    : $"daemon OK（{_daemon.BaseAddress}）")
                : $"daemon 未响应（{_daemon.BaseAddress}）。请先运行 drama-daemon，或把它和本程序放在同一目录。";
            StatusBar.Text = $"{detail} · {_player.BackendDetail}";
            SettingsHealth.Text = detail;
        }
        catch (Exception ex)
        {
            StatusBar.Text = $"daemon：{ex.Message}";
            SettingsHealth.Text = $"daemon：{ex.Message}";
        }
    }

    private void OnNavChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (NavList?.SelectedItem is not ListBoxItem item) return;
        var page = item.Tag?.ToString() ?? "home";
        ShowPage(page);
    }

    private void ShowPage(string page)
    {
        if (page is "home" or "theater" or "search" or "history" or "favorites" or "settings")
        {
            _lastBrowsePage = page;
        }

        _currentPage = page;
        PageHome.IsVisible = page == "home";
        PageTheater.IsVisible = page == "theater";
        PageSearch.IsVisible = page == "search";
        PagePlayer.IsVisible = page == "player";
        PageHistory.IsVisible = page == "history";
        PageFavorites.IsVisible = page == "favorites";
        PageSettings.IsVisible = page == "settings";

        SelectNavSilently(page);
    }

    private void SelectNavSilently(string page)
    {
        foreach (var obj in NavList.Items)
        {
            if (obj is ListBoxItem item && item.Tag?.ToString() == page)
            {
                if (!Equals(NavList.SelectedItem, item))
                {
                    NavList.SelectedItem = item;
                }
                break;
            }
        }
    }

    private async void OnSearch(object? sender, RoutedEventArgs e) => await RunSearchAsync();

    private async void OnSearchKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
        {
            e.Handled = true;
            await RunSearchAsync();
        }
    }

    private async Task RunSearchAsync()
    {
        var q = SearchBox.Text?.Trim() ?? "";
        ShowPage("search");
        if (string.IsNullOrEmpty(q))
        {
            SearchHint.Text = "请输入关键词";
            return;
        }

        SearchHint.Text = "搜索中…";
        try
        {
            var page = await _daemon.SearchAsync(q);
            _search.Clear();
            foreach (var s in page?.Items ?? Enumerable.Empty<SeriesSummary>())
            {
                Remember(s);
                var poster = new PosterItem(s);
                _search.Add(poster);
                _ = LoadCoverAsync(poster);
            }
            SearchHint.Text = _search.Count == 0 ? "无结果" : $"搜索到 {_search.Count} 部";
        }
        catch (Exception ex)
        {
            SearchHint.Text = $"搜索失败：{ex.Message}（确认 daemon 已启动）";
        }
    }

    private async Task RefreshDiscoverAsync()
    {
        HomeHint.Text = "加载推荐…";
        TheaterHint.Text = "加载剧场…";
        try
        {
            var page = await _daemon.DiscoverAsync();
            _home.Clear();
            _theater.Clear();
            foreach (var s in page?.Items ?? Enumerable.Empty<SeriesSummary>())
            {
                Remember(s);
                var home = new PosterItem(s);
                var theater = new PosterItem(s);
                _home.Add(home);
                _theater.Add(theater);
                _ = LoadCoverAsync(home);
                _ = LoadCoverAsync(theater);
            }
            var msg = _home.Count == 0 ? "推荐为空" : $"共 {_home.Count} 部";
            HomeHint.Text = msg + " · 点击海报进入播放页（竖屏预览 + 旁侧选集）";
            TheaterHint.Text = msg + " · 宽屏网格找剧，对齐手机「剧场」瀑布流的内容，形态改为桌面海报墙";
        }
        catch (Exception ex)
        {
            HomeHint.Text = $"推荐失败：{ex.Message}";
            TheaterHint.Text = $"剧场失败：{ex.Message}";
        }
    }

    private void Remember(SeriesSummary series)
    {
        if (!string.IsNullOrWhiteSpace(series.Id))
        {
            _seriesCache[series.Id] = series;
        }
    }

    private async Task LoadCoverAsync(PosterItem item)
    {
        var bmp = await CoverLoader.LoadAsync(item.Series.CoverUrl);
        if (bmp != null) item.Cover = bmp;
    }

    private async Task LoadCoverAsync(HistoryRow row)
    {
        var url = row.Series?.CoverUrl;
        var bmp = await CoverLoader.LoadAsync(url);
        if (bmp != null) row.Cover = bmp;
    }

    private async void OnPosterClick(object? sender, RoutedEventArgs e)
    {
        if (sender is Control { DataContext: PosterItem item })
        {
            await OpenSeriesAsync(item.Series, autoPlay: true);
        }
    }

    private async Task OpenSeriesAsync(SeriesSummary series, bool autoPlay, long seekMs = 0, string? episodeId = null)
    {
        Remember(series);
        _currentSeries = series;
        SeriesTitle.Text = string.IsNullOrWhiteSpace(series.Title) ? series.Id : series.Title;
        ShowPage("player");
        await LoadEpisodesAsync(series);
        await RefreshFavoriteStateAsync();
        await SetPlayerCoverAsync(series.CoverUrl);

        EpisodeItem? target = null;
        if (!string.IsNullOrWhiteSpace(episodeId))
        {
            target = _episodeSnapshot.FirstOrDefault(x => x.Id == episodeId);
        }
        if (target == null && autoPlay)
        {
            var hist = _history.FirstOrDefault(h => h.Raw.SeriesId == series.Id);
            if (hist != null)
            {
                target = _episodeSnapshot.FirstOrDefault(x => x.Id == hist.Raw.EpisodeId);
                if (seekMs <= 0) seekMs = hist.Raw.PositionMs;
            }
            target ??= _episodeSnapshot.FirstOrDefault();
        }

        if (target != null && autoPlay)
        {
            await PlayEpisodeAsync(target, seekMs);
        }
    }

    private async Task SetPlayerCoverAsync(string? url)
    {
        var bmp = await CoverLoader.LoadAsync(url);
        if (bmp != null) PlayerCover.Source = bmp;
    }

    private async Task LoadEpisodesAsync(SeriesSummary series)
    {
        EpisodeHint.Text = "加载分集…";
        try
        {
            var page = await _daemon.EpisodesAsync(series.Id);
            _episodes.Clear();
            _episodeSnapshot = page?.Items?.ToList() ?? new List<EpisodeItem>();
            foreach (var ep in _episodeSnapshot) _episodes.Add(ep);
            EpisodeHint.Text = _episodes.Count == 0 ? "暂无分集" : $"{_episodes.Count} 集 · 点击选集";
        }
        catch (Exception ex)
        {
            EpisodeHint.Text = $"分集失败：{ex.Message}";
        }
    }

    private async void OnEpisodeClick(object? sender, RoutedEventArgs e)
    {
        if (sender is Control { DataContext: EpisodeItem ep })
        {
            await PlayEpisodeAsync(ep, 0);
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
            if (!_playbackCache.TryGetValue(ep.Id, out var resp))
            {
                resp = await _daemon.PlaybackAsync(ep.Id);
                if (resp != null) _playbackCache[ep.Id] = resp;
            }

            _streams = resp?.Playback?.Streams?
                .Where(s => !string.IsNullOrWhiteSpace(s.Url))
                .OrderByDescending(s => s.Height)
                .ToList() ?? new List<PlaybackStream>();
            FillQualityBox();

            var chosen = PlaybackPlanner.PickStream(_streams, _preferredQuality);
            if (chosen == null)
            {
                PlayerStatus.Text = "无可用流 URL";
                return;
            }

            var key = resp?.ContentKey?.Key;
            PlayerStatus.Text =
                $"打开 {PlaybackPlanner.LabelOf(chosen)}…{(resp?.DrmProtected == true ? "（DRM/受保护，best-effort key）" : "")}";

            await _player.OpenAsync(chosen.Url, string.IsNullOrWhiteSpace(key) ? null : key);
            _paused = false;
            if (seekMs > 0)
            {
                await _player.SeekAsync(TimeSpan.FromMilliseconds(seekMs));
            }

            PlayerStatus.Text =
                $"播放中 · {PlaybackPlanner.LabelOf(chosen)} · 竖屏预览在左侧；影像在独立 mpv 窗口";
            await _daemon.HistoryUpsertAsync(new HistoryItem
            {
                SeriesId = _currentSeries?.Id ?? ep.SeriesId,
                EpisodeId = ep.Id,
                PositionMs = seekMs,
                UpdatedAt = DateTimeOffset.UtcNow,
            });
            await RefreshHistoryAsync();
            _ = PrefetchNextAsync();
        }
        catch (Exception ex)
        {
            PlayerStatus.Text = $"播放失败：{ex.Message}";
        }
    }

    private void FillQualityBox()
    {
        _qualityApplying = true;
        try
        {
            QualityBox.Items.Clear();
            QualityBox.Items.Add(new ComboBoxItem { Content = "自动", Tag = "自动" });
            foreach (var stream in _streams)
            {
                var label = PlaybackPlanner.LabelOf(stream);
                QualityBox.Items.Add(new ComboBoxItem { Content = label, Tag = label });
            }

            var idx = 0;
            if (!string.Equals(_preferredQuality, "自动", StringComparison.OrdinalIgnoreCase))
            {
                for (var i = 0; i < QualityBox.Items.Count; i++)
                {
                    if (QualityBox.Items[i] is ComboBoxItem item &&
                        string.Equals(item.Tag?.ToString(), _preferredQuality, StringComparison.OrdinalIgnoreCase))
                    {
                        idx = i;
                        break;
                    }
                }
            }
            QualityBox.SelectedIndex = idx;
        }
        finally
        {
            _qualityApplying = false;
        }
    }

    private async void OnQualityChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (_qualityApplying || QualityBox?.SelectedItem is not ComboBoxItem item) return;
        var next = item.Tag?.ToString() ?? "自动";
        if (string.Equals(next, _preferredQuality, StringComparison.Ordinal)) return;
        _preferredQuality = next;
        if (_currentEpisode != null)
        {
            var pos = TimeSpan.Zero;
            try { pos = await _player.GetPositionAsync(); } catch { /* ignore */ }
            await PlayEpisodeAsync(_currentEpisode, (long)pos.TotalMilliseconds);
        }
    }

    private async Task PrefetchNextAsync()
    {
        var next = PlaybackPlanner.Next(_episodeSnapshot, _currentEpisode?.Id);
        if (next == null || _playbackCache.ContainsKey(next.Id)) return;
        try
        {
            var resp = await _daemon.PlaybackAsync(next.Id);
            if (resp != null)
            {
                _playbackCache[next.Id] = resp;
                StatusBar.Text = $"已预加载下一集 {next.ListLabel}";
            }
        }
        catch
        {
            // prefetch is best-effort
        }
    }

    private async void OnPlaybackEnded()
    {
        await Dispatcher.UIThread.InvokeAsync(async () =>
        {
            if (AutoNextBox.IsChecked != true || _currentEpisode == null) return;
            var next = PlaybackPlanner.Next(_episodeSnapshot, _currentEpisode.Id);
            if (next == null) return;
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

    private async void OnTogglePause(object? sender, RoutedEventArgs e)
    {
        try
        {
            // Resume if we can; if already playing, pause. Host has no IsPaused, so toggle via pause then
            // the UI treats this as play/pause pair: try Resume first after Pause is explicit.
            // Use a simple heuristic: always pause if TimerHint says playing? Better: send pause/resume via
            // GetPosition succeeding and treat consecutive clicks as toggle by tracking flag.
        }
        catch { /* fall through */ }
        await TogglePauseCoreAsync();
    }

    private bool _paused;

    private async Task TogglePauseCoreAsync()
    {
        if (_currentEpisode == null)
        {
            PlayerStatus.Text = "还没有在播放";
            return;
        }

        if (_paused)
        {
            await _player.ResumeAsync();
            _paused = false;
            PlayerStatus.Text = "继续播放";
        }
        else
        {
            await _player.PauseAsync();
            _paused = true;
            PlayerStatus.Text = "已暂停";
        }
    }

    private async void OnStop(object? sender, RoutedEventArgs e)
    {
        await PersistProgressAsync();
        await _player.StopAsync();
        _paused = true;
        PlayerStatus.Text = "已停止";
    }

    private async void OnMute(object? sender, RoutedEventArgs e)
    {
        await _player.ToggleMuteAsync();
        StatusBar.Text = "已切换静音";
    }

    private async void OnPrevEpisode(object? sender, RoutedEventArgs e)
    {
        var prev = PlaybackPlanner.Previous(_episodeSnapshot, _currentEpisode?.Id);
        if (prev == null)
        {
            StatusBar.Text = "已经是第一集";
            return;
        }
        await PlayEpisodeAsync(prev, 0);
    }

    private async void OnNextEpisode(object? sender, RoutedEventArgs e)
    {
        var next = PlaybackPlanner.Next(_episodeSnapshot, _currentEpisode?.Id);
        if (next == null)
        {
            StatusBar.Text = "已经是最后一集";
            return;
        }
        await PlayEpisodeAsync(next, 0);
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
                _paused = true;
                TimerHint.Text = "定时停止已触发";
                PlayerStatus.Text = "定时停止已触发";
                StopAfterBox.SelectedIndex = 0;
            }
            else
            {
                TimerHint.Text = $"定时停止倒计时 {left.Minutes:00}:{left.Seconds % 60:00}";
            }
        };
        _stopTimer.Start();
    }

    private async void OnFavoriteToggle(object? sender, RoutedEventArgs e)
    {
        if (_currentSeries == null) return;
        try
        {
            if (_favorited)
            {
                await _daemon.FavoritesRemoveAsync(_currentSeries.Id);
                _favorited = false;
            }
            else
            {
                await _daemon.FavoritesAddAsync(_currentSeries.Id);
                _favorited = true;
            }
            UpdateFavButton();
            await RefreshFavoritesAsync();
            StatusBar.Text = _favorited ? $"已收藏 {_currentSeries.Title}" : $"已取消收藏 {_currentSeries.Title}";
        }
        catch (Exception ex)
        {
            StatusBar.Text = $"收藏失败：{ex.Message}";
        }
    }

    private async Task RefreshFavoriteStateAsync()
    {
        if (_currentSeries == null)
        {
            _favorited = false;
            UpdateFavButton();
            return;
        }

        try
        {
            var page = await _daemon.FavoritesListAsync();
            _favorited = page?.SeriesIds?.Contains(_currentSeries.Id) == true;
        }
        catch
        {
            _favorited = false;
        }
        UpdateFavButton();
    }

    private void UpdateFavButton()
    {
        FavToggleBtn.Content = _favorited ? "已收藏" : "收藏";
    }

    private async Task RefreshHistoryAsync()
    {
        try
        {
            var page = await _daemon.HistoryListAsync();
            _history.Clear();
            foreach (var h in page?.Items ?? Enumerable.Empty<HistoryItem>())
            {
                _seriesCache.TryGetValue(h.SeriesId, out var series);
                string? epLabel = null;
                if (_currentSeries?.Id == h.SeriesId)
                {
                    epLabel = _episodeSnapshot.FirstOrDefault(x => x.Id == h.EpisodeId)?.ListLabel;
                }
                var row = new HistoryRow(h, series, epLabel);
                _history.Add(row);
                _ = LoadCoverAsync(row);
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
            var ids = page?.SeriesIds ?? new List<string>();
            FavoritesHint.Text = ids.Count == 0 ? "还没有收藏" : $"共 {ids.Count} 部";
            foreach (var id in ids)
            {
                if (!_seriesCache.TryGetValue(id, out var series))
                {
                    series = new SeriesSummary { Id = id, Title = id };
                }
                var poster = new PosterItem(series);
                _favorites.Add(poster);
                _ = LoadCoverAsync(poster);
            }
        }
        catch
        {
            FavoritesHint.Text = "无法读取收藏（daemon 未响应）";
        }
    }

    private async void OnHistoryActivate(object? sender, Avalonia.Input.TappedEventArgs e)
    {
        if (HistoryList.SelectedItem is not HistoryRow row) return;
        var series = row.Series ?? new SeriesSummary { Id = row.Raw.SeriesId, Title = row.Title };
        await OpenSeriesAsync(series, autoPlay: true, seekMs: row.Raw.PositionMs, episodeId: row.Raw.EpisodeId);
    }

    private async void OnWindowKeyDown(object? sender, KeyEventArgs e)
    {
        var inText = SearchBox?.IsFocused == true ||
                     TopLevel.GetTopLevel(this)?.FocusManager?.GetFocusedElement() is TextBox;
        if (inText && e.Key is not (Key.Escape or Key.F or Key.H)) return;

        var ctrl = e.KeyModifiers.HasFlag(KeyModifiers.Control);
        switch (e.Key)
        {
            case Key.Space when !inText:
                e.Handled = true;
                await TogglePauseCoreAsync();
                break;
            case Key.Left when !inText:
                e.Handled = true;
                await _player.SeekByAsync(TimeSpan.FromSeconds(-5));
                break;
            case Key.Right when !inText:
                e.Handled = true;
                await _player.SeekByAsync(TimeSpan.FromSeconds(5));
                break;
            case Key.Up or Key.PageUp when !inText:
                e.Handled = true;
                OnPrevEpisode(this, new RoutedEventArgs());
                break;
            case Key.Down or Key.PageDown when !inText:
                e.Handled = true;
                OnNextEpisode(this, new RoutedEventArgs());
                break;
            case Key.M when !inText:
                e.Handled = true;
                await _player.ToggleMuteAsync();
                break;
            case Key.F when ctrl:
                e.Handled = true;
                SearchBox?.Focus();
                break;
            case Key.H when ctrl:
                e.Handled = true;
                OnHideToTray(this, new RoutedEventArgs());
                break;
            case Key.Escape:
                e.Handled = true;
                if (_currentPage == "player") ShowPage(_lastBrowsePage);
                break;
        }
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

    private async void OnAbout(object? sender, RoutedEventArgs e)
    {
        await EnsureDaemonAsync();
        ShowPage("settings");
    }

    private void ShowFromTray()
    {
        Show();
        Activate();
        if (_tray != null) _tray.IsVisible = false;
    }

    protected override async void OnClosed(EventArgs e)
    {
        _stopTimer?.Stop();
        _progressTimer?.Stop();
        try { await PersistProgressAsync(); } catch { /* ignore */ }
        _player.PlaybackEnded -= OnPlaybackEnded;
        _player.Dispose();
        _supervisor.Dispose();
        _daemon.Dispose();
        _tray?.Dispose();
        base.OnClosed(e);
    }
}

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
