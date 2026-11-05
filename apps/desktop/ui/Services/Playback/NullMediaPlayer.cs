namespace DramaRed.UI.Services.Playback;

/// <summary>Fallback when no native mpv backend is available.</summary>
public sealed class NullMediaPlayer : IMediaPlayer
{
    public bool AutoNext { get; set; } = true;
    public double Rate { get; set; } = 1.0;
    public TimeSpan? StopAfter { get; set; }

    public Task OpenAsync(string url, string? contentKeyHex = null, CancellationToken ct = default) =>
        throw new InvalidOperationException(
            "No media backend available. Install system libmpv (Linux/macOS) or place libmpv-2.dll beside the app (Windows).");

    public Task PauseAsync(CancellationToken ct = default) => Task.CompletedTask;
    public Task ResumeAsync(CancellationToken ct = default) => Task.CompletedTask;
    public Task StopAsync(CancellationToken ct = default) => Task.CompletedTask;
    public void Dispose() { }
}
