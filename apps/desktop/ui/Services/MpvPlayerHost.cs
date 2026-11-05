using DramaRed.UI.Services.Playback;

namespace DramaRed.UI.Services;

/// <summary>Compatibility façade over <see cref="IMediaPlayer"/>.</summary>
public sealed class MpvPlayerHost : IDisposable
{
    private readonly IMediaPlayer _player;
    public string BackendDetail { get; }

    public MpvPlayerHost()
    {
        _player = MediaPlayerFactory.Create(out var detail);
        BackendDetail = detail;
    }

    public bool AutoNext { get => _player.AutoNext; set => _player.AutoNext = value; }
    public double Rate { get => _player.Rate; set => _player.Rate = value; }
    public TimeSpan? StopAfter { get => _player.StopAfter; set => _player.StopAfter = value; }

    public Task OpenAsync(string url, string? contentKey = null, CancellationToken ct = default) =>
        _player.OpenAsync(url, contentKey, ct);

    public void Dispose() => _player.Dispose();
}
