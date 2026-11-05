using DramaRed.UI.Services.Playback;

namespace DramaRed.UI.Services;

/// <summary>Compatibility façade over <see cref="IMediaPlayer"/>.</summary>
public sealed class MpvPlayerHost : IDisposable
{
    private readonly IMediaPlayer _player;
    public string BackendDetail { get; }
    public bool IsNullBackend { get; }

    public MpvPlayerHost()
    {
        IsNullBackend = !LibMpvMediaPlayer.TryCreate(out _player, out var detail);
        if (IsNullBackend)
        {
            _player = new NullMediaPlayer();
            BackendDetail = detail;
        }
        else
        {
            BackendDetail = detail;
        }
    }

    public bool AutoNext { get => _player.AutoNext; set => _player.AutoNext = value; }
    public double Rate { get => _player.Rate; set => _player.Rate = value; }
    public TimeSpan? StopAfter { get => _player.StopAfter; set => _player.StopAfter = value; }

    public event Action? PlaybackEnded
    {
        add => _player.PlaybackEnded += value;
        remove => _player.PlaybackEnded -= value;
    }

    public Task OpenAsync(string url, string? contentKey = null, CancellationToken ct = default) =>
        _player.OpenAsync(url, contentKey, ct);

    public Task PauseAsync(CancellationToken ct = default) => _player.PauseAsync(ct);
    public Task ResumeAsync(CancellationToken ct = default) => _player.ResumeAsync(ct);
    public Task StopAsync(CancellationToken ct = default) => _player.StopAsync(ct);
    public Task SeekAsync(TimeSpan position, CancellationToken ct = default) => _player.SeekAsync(position, ct);
    public Task SeekByAsync(TimeSpan delta, CancellationToken ct = default) => _player.SeekByAsync(delta, ct);
    public Task ToggleMuteAsync(CancellationToken ct = default) => _player.ToggleMuteAsync(ct);
    public Task<TimeSpan> GetPositionAsync(CancellationToken ct = default) => _player.GetPositionAsync(ct);

    public void Dispose() => _player.Dispose();
}
