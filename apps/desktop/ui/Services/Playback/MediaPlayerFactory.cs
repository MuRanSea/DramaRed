namespace DramaRed.UI.Services.Playback;

public static class MediaPlayerFactory
{
    public static IMediaPlayer Create(out string backendDetail)
    {
        if (LibMpvMediaPlayer.TryCreate(out var player, out backendDetail))
        {
            return player;
        }

        return new NullMediaPlayer();
    }
}
