namespace DramaRed.UI.Services;

/// <summary>
/// libmpv 宿主占位。后续用 mpv HWND/OpenGL 控件嵌入主窗口。
/// 预留：清晰度切换、倍速、自动连播、定时停止、后台继续听。
/// </summary>
public sealed class MpvPlayerHost : IDisposable
{
    public bool AutoNext { get; set; } = true;
    public double Rate { get; set; } = 1.0;
    public TimeSpan? StopAfter { get; set; }

    public void Open(string url, string? contentKey = null)
    {
        // TODO: mpv command loadfile; configure ClearKey/DRM if needed
        _ = url;
        _ = contentKey;
        throw new NotImplementedException("MpvPlayerHost.Open — scaffold only");
    }

    public void Pause() { }
    public void Resume() { }
    public void Stop() { }
    public void Dispose() { }
}
