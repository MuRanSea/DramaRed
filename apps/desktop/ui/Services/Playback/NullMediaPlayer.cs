namespace DramaRed.UI.Services.Playback;

/// <summary>Fallback when no native mpv backend is available.</summary>
public sealed class NullMediaPlayer : IMediaPlayer
{
    public bool AutoNext { get; set; } = true;
    public double Rate { get; set; } = 1.0;
    public TimeSpan? StopAfter { get; set; }

    public event Action? PlaybackEnded
    {
        add { }
        remove { }
    }

    public Task OpenAsync(string url, string? contentKeyHex = null, CancellationToken ct = default) =>
        throw new InvalidOperationException(
            "当前无法播放：缺少 libmpv。请确认程序目录有 libmpv-2.dll（Windows 发布包已捆绑），或在系统中安装 libmpv。");

    public Task PauseAsync(CancellationToken ct = default) => Task.CompletedTask;
    public Task ResumeAsync(CancellationToken ct = default) => Task.CompletedTask;
    public Task StopAsync(CancellationToken ct = default) => Task.CompletedTask;
    public Task SeekAsync(TimeSpan position, CancellationToken ct = default) => Task.CompletedTask;
    public Task SeekByAsync(TimeSpan delta, CancellationToken ct = default) => Task.CompletedTask;
    public Task ToggleMuteAsync(CancellationToken ct = default) => Task.CompletedTask;
    public Task<TimeSpan> GetPositionAsync(CancellationToken ct = default) => Task.FromResult(TimeSpan.Zero);

    public void Dispose() { }

    public void SetVideoWindowVisible(bool visible) { }
}
