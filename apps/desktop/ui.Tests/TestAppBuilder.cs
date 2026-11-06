using Avalonia;
using Avalonia.Headless;
using Avalonia.Headless.XUnit;
using DramaRed.UI;

[assembly: AvaloniaTestApplication(typeof(DramaRed.UI.Tests.TestAppBuilder))]

namespace DramaRed.UI.Tests;

public class TestAppBuilder
{
    public static AppBuilder BuildAvaloniaApp() =>
        AppBuilder.Configure<App>()
            .UseHeadless(new AvaloniaHeadlessPlatformOptions());
}
