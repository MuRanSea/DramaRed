using DramaRed.UI.Services.Playback;
using Xunit;

namespace DramaRed.UI.Tests;

public class LibMpvBundleTests
{
    [Fact]
    public void Windows_candidates_prefer_libmpv_beside_exe()
    {
        var baseDir = "/app/DramaRed-desktop-win-x64";
        var list = LibMpvMediaPlayer.WindowsCandidateLibraries(baseDir).ToList();
        Assert.Equal(Path.Combine(baseDir, "libmpv-2.dll"), list[0]);
        Assert.Contains("libmpv-2.dll", list);
        Assert.Contains(Path.Combine(baseDir, "mpv-2.dll"), list);
    }

    [Fact]
    public async Task NullMediaPlayer_open_throws_chinese()
    {
        var p = new NullMediaPlayer();
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => p.OpenAsync("http://x", ct: TestContext.Current.CancellationToken));
        Assert.Contains("缺少 libmpv", ex.Message);
        Assert.DoesNotContain("No media backend available", ex.Message);
    }
}
