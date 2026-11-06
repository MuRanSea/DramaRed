using System.Text.Json.Serialization;

namespace DramaRed.UI.Models;

public sealed class SeriesSummary
{
    [JsonPropertyName("id")] public string Id { get; set; } = "";
    [JsonPropertyName("title")] public string Title { get; set; } = "";
    [JsonPropertyName("description")] public string Description { get; set; } = "";
    [JsonPropertyName("cover_url")] public string CoverUrl { get; set; } = "";
    [JsonPropertyName("episode_count")] public int EpisodeCount { get; set; }
    [JsonPropertyName("author")] public string Author { get; set; } = "";
    [JsonPropertyName("category")] public string Category { get; set; } = "";

    public string ListLabel =>
        string.IsNullOrWhiteSpace(Title) ? Id :
        EpisodeCount > 0 ? $"{Title}（{EpisodeCount} 集）" : Title;
}

public sealed class EpisodeItem
{
    [JsonPropertyName("id")] public string Id { get; set; } = "";
    [JsonPropertyName("series_id")] public string SeriesId { get; set; } = "";
    [JsonPropertyName("number")] public int Number { get; set; }
    [JsonPropertyName("title")] public string Title { get; set; } = "";
    [JsonPropertyName("playable")] public bool Playable { get; set; }

    public string ListLabel
    {
        get
        {
            var num = Number > 0 ? $"第 {Number} 集" : "";
            var title = (Title ?? "").Trim();
            if (string.IsNullOrEmpty(title))
                return string.IsNullOrEmpty(num) ? Id : num;
            // Upstream often sets Title to "第N集" / "第 N 集" — never double it.
            if (LooksLikeEpisodeNumberTitle(title))
                return string.IsNullOrEmpty(num) ? title : num;
            return string.IsNullOrEmpty(num) ? title : $"{num} · {title}";
        }
    }

    public string ChipLabel => Number > 0 ? $"第 {Number} 集" : (string.IsNullOrWhiteSpace(Title) ? Id : Title);

    private static bool LooksLikeEpisodeNumberTitle(string title) =>
        System.Text.RegularExpressions.Regex.IsMatch(title, @"^第\s*\d+\s*集$");
}

public sealed class PageResult<T>
{
    [JsonPropertyName("items")] public List<T> Items { get; set; } = new();
    [JsonPropertyName("has_more")] public bool HasMore { get; set; }
}

public sealed class PlaybackStream
{
    [JsonPropertyName("definition")] public string Definition { get; set; } = "";
    [JsonPropertyName("quality")] public string Quality { get; set; } = "";
    [JsonPropertyName("height")] public int Height { get; set; }
    [JsonPropertyName("url")] public string Url { get; set; } = "";
    [JsonPropertyName("protected")] public bool Protected { get; set; }
}

public sealed class PlaybackModel
{
    [JsonPropertyName("episode_id")] public string EpisodeId { get; set; } = "";
    [JsonPropertyName("protected")] public bool Protected { get; set; }
    [JsonPropertyName("streams")] public List<PlaybackStream> Streams { get; set; } = new();
}

public sealed class PlaybackResponse
{
    [JsonPropertyName("playback")] public PlaybackModel? Playback { get; set; }
    [JsonPropertyName("warning")] public string? Warning { get; set; }
    [JsonPropertyName("drmProtected")] public bool DrmProtected { get; set; }
    [JsonPropertyName("contentKey")] public ContentKeyPayload? ContentKey { get; set; }
}

public sealed class ContentKeyPayload
{
    [JsonPropertyName("key")] public string Key { get; set; } = "";
}

public sealed class HistoryItem
{
    [JsonPropertyName("seriesId")] public string SeriesId { get; set; } = "";
    [JsonPropertyName("episodeId")] public string EpisodeId { get; set; } = "";
    [JsonPropertyName("positionMs")] public long PositionMs { get; set; }
    [JsonPropertyName("updatedAt")] public DateTimeOffset UpdatedAt { get; set; }

    public string ListLabel =>
        $"{SeriesId} / ep={EpisodeId} @ {PositionMs}ms";
}

public sealed class HistoryListResponse
{
    [JsonPropertyName("items")] public List<HistoryItem> Items { get; set; } = new();
}

public sealed class FavoritesListResponse
{
    [JsonPropertyName("seriesIds")] public List<string> SeriesIds { get; set; } = new();
}

public sealed class PosterItem : System.ComponentModel.INotifyPropertyChanged
{
    public PosterItem(SeriesSummary series) => Series = series;

    public SeriesSummary Series { get; }
    public string Id => Series.Id;
    public string Title => string.IsNullOrWhiteSpace(Series.Title) ? Series.Id : Series.Title;
    public string Meta
    {
        get
        {
            var bits = new List<string>();
            if (Series.EpisodeCount > 0) bits.Add($"{Series.EpisodeCount} 集");
            if (!string.IsNullOrWhiteSpace(Series.Category)) bits.Add(Series.Category);
            if (!string.IsNullOrWhiteSpace(Series.Author)) bits.Add(Series.Author);
            return string.Join(" · ", bits);
        }
    }

    private Avalonia.Media.Imaging.Bitmap? _cover;
    public Avalonia.Media.Imaging.Bitmap? Cover
    {
        get => _cover;
        set
        {
            _cover = value;
            PropertyChanged?.Invoke(this, new(nameof(Cover)));
        }
    }

    public event System.ComponentModel.PropertyChangedEventHandler? PropertyChanged;
}

public sealed class HistoryRow : System.ComponentModel.INotifyPropertyChanged
{
    public HistoryRow(HistoryItem raw, SeriesSummary? series, string? episodeLabel)
    {
        Raw = raw;
        Series = series;
        Title = string.IsNullOrWhiteSpace(series?.Title) ? raw.SeriesId : series!.Title;
        Subtitle = string.IsNullOrWhiteSpace(episodeLabel)
            ? $"ep={raw.EpisodeId} · {FormatPosition(raw.PositionMs)}"
            : $"{episodeLabel} · {FormatPosition(raw.PositionMs)}";
        Updated = raw.UpdatedAt.ToLocalTime().ToString("yyyy-MM-dd HH:mm");
    }

    public HistoryItem Raw { get; }
    public SeriesSummary? Series { get; }
    public string Title { get; }
    public string Subtitle { get; }
    public string Updated { get; }

    private Avalonia.Media.Imaging.Bitmap? _cover;
    public Avalonia.Media.Imaging.Bitmap? Cover
    {
        get => _cover;
        set
        {
            _cover = value;
            PropertyChanged?.Invoke(this, new(nameof(Cover)));
        }
    }

    public event System.ComponentModel.PropertyChangedEventHandler? PropertyChanged;

    private static string FormatPosition(long ms)
    {
        if (ms <= 0) return "开头";
        var ts = TimeSpan.FromMilliseconds(ms);
        return ts.TotalHours >= 1 ? ts.ToString(@"h\:mm\:ss") : ts.ToString(@"mm\:ss");
    }
}
