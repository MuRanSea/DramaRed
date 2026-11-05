using DramaRed.UI.Services.Playback;

// Headless/display smoke for LibMpvMediaPlayer.OpenAsync
if (!LibMpvMediaPlayer.TryCreate(out var player, out var detail))
{
    Console.WriteLine("FAIL create: " + detail);
    return 2;
}
Console.WriteLine("OK create: " + detail);
try
{
    // Public domain short sample (or local file if present)
    var url = args.Length > 0 ? args[0] : "https://filesamples.com/samples/video/mp4/sample_640x360.mp4";
    Console.WriteLine("Opening " + url);
    await player.OpenAsync(url);
    Console.WriteLine("OpenAsync returned");
    await Task.Delay(3000);
    var pos = await player.GetPositionAsync();
    Console.WriteLine($"position={pos.TotalSeconds:0.0}s");
    await player.PauseAsync();
    Console.WriteLine("paused OK");
    player.Dispose();
    Console.WriteLine("PASS");
    return 0;
}
catch (Exception ex)
{
    Console.WriteLine("FAIL open: " + ex);
    player.Dispose();
    return 1;
}
