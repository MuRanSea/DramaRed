namespace DramaRed.UI.Services.Playback;

/// <summary>
/// Cross-platform playback abstraction. Implementations load libmpv from the OS
/// (Linux/macOS) or an optional Windows DLL — never hard-require Win32.
/// </summary>
public interface IMediaPlayer : IDisposable
{
    bool AutoNext { get; set; }
    double Rate { get; set; }
    TimeSpan? StopAfter { get; set; }

    /// <summary>Raised when the current file ends (for auto-next).</summary>
    event Action? PlaybackEnded;

    /// <summary>Open a media URL. <paramref name="contentKeyHex"/> is optional ClearKey material.</summary>
    Task OpenAsync(string url, string? contentKeyHex = null, CancellationToken ct = default);

    Task PauseAsync(CancellationToken ct = default);
    Task ResumeAsync(CancellationToken ct = default);
    Task StopAsync(CancellationToken ct = default);
    Task SeekAsync(TimeSpan position, CancellationToken ct = default);
    Task SeekByAsync(TimeSpan delta, CancellationToken ct = default);
    Task ToggleMuteAsync(CancellationToken ct = default);
    Task<TimeSpan> GetPositionAsync(CancellationToken ct = default);

    /// <summary>Show or hide the external libmpv video window (browse pages must not be covered).</summary>
    void SetVideoWindowVisible(bool visible);
}
