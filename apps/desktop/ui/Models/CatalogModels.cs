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

    public string ListLabel =>
        string.IsNullOrWhiteSpace(Title) ? $"第 {Number} 集" : $"第 {Number} 集 · {Title}";
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
