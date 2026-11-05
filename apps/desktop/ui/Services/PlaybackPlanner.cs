using DramaRed.UI.Models;

namespace DramaRed.UI.Services;

/// <summary>Pure helpers for quality pick and episode adjacency (unit-testable).</summary>
public static class PlaybackPlanner
{
    public static PlaybackStream? PickStream(IEnumerable<PlaybackStream>? streams, string? preferred)
    {
        var list = streams?
            .Where(s => !string.IsNullOrWhiteSpace(s.Url))
            .ToList() ?? new List<PlaybackStream>();
        if (list.Count == 0) return null;

        if (!string.IsNullOrWhiteSpace(preferred) &&
            !string.Equals(preferred, "自动", StringComparison.OrdinalIgnoreCase))
        {
            var match = list.FirstOrDefault(s =>
                string.Equals(LabelOf(s), preferred, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(s.Definition, preferred, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(s.Quality, preferred, StringComparison.OrdinalIgnoreCase));
            if (match != null) return match;
        }

        return list.OrderByDescending(s => s.Height).First();
    }

    public static string LabelOf(PlaybackStream s) =>
        !string.IsNullOrWhiteSpace(s.Definition) ? s.Definition :
        !string.IsNullOrWhiteSpace(s.Quality) ? s.Quality :
        s.Height > 0 ? $"{s.Height}p" : "stream";

    public static EpisodeItem? Next(IReadOnlyList<EpisodeItem> episodes, string? currentId)
    {
        if (episodes.Count == 0 || string.IsNullOrWhiteSpace(currentId)) return null;
        var idx = IndexOf(episodes, currentId);
        return idx >= 0 && idx + 1 < episodes.Count ? episodes[idx + 1] : null;
    }

    public static EpisodeItem? Previous(IReadOnlyList<EpisodeItem> episodes, string? currentId)
    {
        if (episodes.Count == 0 || string.IsNullOrWhiteSpace(currentId)) return null;
        var idx = IndexOf(episodes, currentId);
        return idx > 0 ? episodes[idx - 1] : null;
    }

    private static int IndexOf(IReadOnlyList<EpisodeItem> episodes, string currentId)
    {
        for (var i = 0; i < episodes.Count; i++)
        {
            if (episodes[i].Id == currentId) return i;
        }
        return -1;
    }
}
