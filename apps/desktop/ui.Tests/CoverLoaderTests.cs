using DramaRed.UI.Services;
using Xunit;

namespace DramaRed.UI.Tests;

public class CoverLoaderTests
{
    [Fact]
    public void Placeholder_is_non_null_bitmap()
    {
        var bmp = CoverLoader.Placeholder;
        Assert.NotNull(bmp);
        Assert.True(bmp.PixelSize.Width >= 1);
        Assert.True(bmp.PixelSize.Height >= 1);
        Assert.Same(bmp, CoverLoader.Placeholder);
    }

    [Fact]
    public void FindFfmpeg_prefers_file_beside_base_directory()
    {
        CoverLoader.ResetForTests();
        var name = OperatingSystem.IsWindows() ? "ffmpeg.exe" : "ffmpeg";
        var bundled = Path.Combine(AppContext.BaseDirectory, name);
        var created = false;
        try
        {
            if (!File.Exists(bundled))
            {
                File.WriteAllText(bundled, "#!/bin/true\n");
                created = true;
            }

            var path = CoverLoader.FindFfmpeg();
            Assert.Equal(Path.GetFullPath(bundled), Path.GetFullPath(path!));
        }
        finally
        {
            if (created)
            {
                try { File.Delete(bundled); } catch { /* ignore */ }
            }
            CoverLoader.ResetForTests();
        }
    }
}
